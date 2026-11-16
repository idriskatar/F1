#!/usr/bin/env python3
"""FastF1 verisinden F1 Tracker için küçük, sıkıştırılmış "replay" dosyaları üretir.

Çıktı (varsayılan: data/replay/):
    index.json                    -> hazır seansların listesi (uygulama önce bunu okur)
    <yıl>/r<tur>-<seans>.json.gz  -> tek bir seansın replay verisi (şema aşağıda)

Şema (version 1) — Flutter tarafı (lib/core/models/replay_models.dart) ile birebir aynıdır:
    {
      "version": 1,
      "event": {"year", "round", "session", "name", "country", "circuit"},
      "hz": 2,                       # örnekleme sıklığı; i. örnek = i / hz saniye
      "duration": 5400.0,            # replay süresi (sn); t=0 yarış başlangıcı
      "totalLaps": 57,
      "lapStarts": [0.0, 95.2, ...], # kazananın tur başlangıçları (sn) -> tur sayacı
      "track": {"x": [...], "y": [...]},       # pist çizgisi (FastF1 konum birimi, 1/10 m)
      "drivers": [{
          "number", "code", "name", "team", "color", "position",
          "x": [...], "y": [...],                # veri yoksa null
          "speed", "gear", "throttle", "brake", "drs"   # isteğe bağlı kanallar
      }],
      "pits": [{"driver": "VER", "lap": 12, "in": 1234.5, "out": 1257.0, "pitLane": 22.5}]
    }

Notlar:
  * "pitLane" pit şeridinde geçen süredir (giriş -> çıkış), lastik değişim anındaki
    duruş süresi DEĞİLDİR; FastF1 duruş süresini vermez.
  * Veri seanstan ~30-120 dk sonra yayınlanır. Eksik/yarım veri "tamamlandı" sayılmaz
    (validate_payload); betik bir sonraki çalışmada yeniden dener.
"""
from __future__ import annotations

import argparse
import gzip
import json
import math
import os
import sys
import tempfile
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Optional

import numpy as np
import pandas as pd

SCHEMA_VERSION = 1
DEFAULT_HZ = 2
MAX_GAP_SECONDS = 3.0      # kaynak örnekler arasında bundan büyük boşluk -> veri yok (null)
DRS_OPEN_MIN = 10          # FastF1 DRS kodu: 10/12/14 = açık, 8 = açılabilir, 0/1 = kapalı
TRACK_MAX_POINTS = 400
FALLBACK_COLOR = "#9AA0A6"


class IncompleteData(RuntimeError):
    """Kaynak henüz tam yayınlanmamış ya da veri kalitesi yetersiz."""


@dataclass
class RawSession:
    """FastF1'den bağımsız, test edilebilir ara temsil."""

    year: int
    round: int
    code: str
    event_name: str
    country: str
    circuit: str
    results: list[dict[str, Any]]
    laps: pd.DataFrame
    car: dict[str, pd.DataFrame] = field(default_factory=dict)
    pos: dict[str, pd.DataFrame] = field(default_factory=dict)


# --------------------------------------------------------------------------- yardımcılar

def _seconds(series: pd.Series) -> np.ndarray:
    """Timedelta serisini saniyeye çevirir; NaT -> NaN."""
    if pd.api.types.is_datetime64_any_dtype(series):
        # Tamamen NaT olan kolonlar (ör. hiç pit yok) bazen datetime türünde gelir; oturum
        # zamanı olarak yorumlanamaz, hepsi "yok" sayılır.
        return np.full(len(series), np.nan)
    td = pd.to_timedelta(series, errors="coerce")
    return td.dt.total_seconds().to_numpy(dtype=float, na_value=np.nan)


def _clean(value: Any, default: str = "") -> str:
    if value is None:
        return default
    if isinstance(value, float) and math.isnan(value):
        return default
    text = str(value).strip()
    return text if text else default


def _color(value: Any) -> str:
    text = _clean(value).lstrip("#")
    if len(text) == 6 and all(c in "0123456789abcdefABCDEF" for c in text):
        return "#" + text.upper()
    return FALLBACK_COLOR


def _prepare(df: pd.DataFrame, columns: list[str]) -> tuple[np.ndarray, dict[str, np.ndarray]]:
    """Zamana göre sıralı, tekrarsız (t, {kolon: değerler}) döndürür."""
    t = _seconds(df["SessionTime"])
    keep = ~np.isnan(t)
    t = t[keep]
    uniq, first = np.unique(t, return_index=True)
    values = {}
    for col in columns:
        if col in df.columns:
            raw = pd.to_numeric(df[col], errors="coerce")
            values[col] = raw.to_numpy(dtype=float, na_value=np.nan)[keep][first]
    return uniq, values


def _coverage(t_src: np.ndarray, grid: np.ndarray, max_gap: float) -> tuple[np.ndarray, np.ndarray]:
    """grid noktalarında kaynak verinin güvenilir olduğu yerleri ve 'önceki örnek' indeksini verir."""
    if len(t_src) == 0:
        return np.zeros(grid.shape, dtype=bool), np.zeros(grid.shape, dtype=int)
    right = np.searchsorted(t_src, grid, side="right")
    left = right - 1
    valid = (left >= 0) & (right < len(t_src))
    gap = np.full(grid.shape, np.inf)
    gap[valid] = t_src[right[valid]] - t_src[left[valid]]
    return valid & (gap <= max_gap), np.clip(left, 0, len(t_src) - 1)


def _linear(t_src: np.ndarray, v_src: np.ndarray, grid: np.ndarray, max_gap: float = MAX_GAP_SECONDS) -> np.ndarray:
    ok, _ = _coverage(t_src, grid, max_gap)
    out = np.full(grid.shape, np.nan)
    if len(t_src) >= 2:
        out[ok] = np.interp(grid[ok], t_src, v_src)
    return out


def _step(t_src: np.ndarray, v_src: np.ndarray, grid: np.ndarray, max_gap: float = MAX_GAP_SECONDS) -> np.ndarray:
    ok, left = _coverage(t_src, grid, max_gap)
    out = np.full(grid.shape, np.nan)
    if len(t_src) >= 2:
        out[ok] = v_src[left[ok]]
    return out


def _to_list(arr: np.ndarray) -> list[Optional[int]]:
    return [None if math.isnan(v) else int(v) for v in np.rint(arr).tolist()]


# --------------------------------------------------------------------------- hesaplama

def race_window(laps: pd.DataFrame) -> tuple[float, float]:
    """Replay'in başlangıç (t0) ve bitiş (t1) oturum zamanı."""
    starts = _seconds(laps["LapStartTime"])
    lap_no = pd.to_numeric(laps["LapNumber"], errors="coerce").to_numpy(dtype=float, na_value=np.nan)
    first = starts[(lap_no == 1) & ~np.isnan(starts)]
    if len(first):
        t0 = float(first.min())
    elif np.any(~np.isnan(starts)):
        t0 = float(np.nanmin(starts))
    else:
        raise IncompleteData("Tur başlangıç zamanları yok.")
    ends = _seconds(laps["Time"])
    if not np.any(~np.isnan(ends)):
        raise IncompleteData("Tur bitiş zamanları yok.")
    t1 = float(np.nanmax(ends))
    if t1 <= t0:
        raise IncompleteData("Yarış penceresi geçersiz.")
    return t0, t1


def extract_pits(laps: pd.DataFrame, codes: dict[str, str], t0: float) -> list[dict[str, Any]]:
    """Pit giriş/çıkışlarını (replay saniyesi) çıkarır."""
    pits: list[dict[str, Any]] = []
    for number, group in laps.groupby("DriverNumber"):
        number = str(number)
        if number not in codes:
            continue
        g = group.sort_values("LapNumber")
        lap_no = pd.to_numeric(g["LapNumber"], errors="coerce").to_numpy(dtype=float, na_value=np.nan)
        pit_in = _seconds(g["PitInTime"])
        pit_out = _seconds(g["PitOutTime"])
        for i in range(len(g)):
            if np.isnan(pit_in[i]) or pit_in[i] < t0:
                continue
            t_in = pit_in[i] - t0
            t_out = None
            # Çıkış, sonraki turun PitOutTime alanındadır.
            nxt = np.where(lap_no == lap_no[i] + 1)[0]
            if len(nxt) and not np.isnan(pit_out[nxt[0]]):
                t_out = pit_out[nxt[0]] - t0
                if t_out < t_in:
                    t_out = None
            pits.append({
                "driver": codes[number],
                "lap": int(lap_no[i]),
                "in": round(t_in, 1),
                "out": None if t_out is None else round(t_out, 1),
                "pitLane": None if t_out is None else round(t_out - t_in, 1),
            })
    pits.sort(key=lambda p: (p["in"], p["driver"]))
    return pits


def track_outline(raw: RawSession, max_points: int = TRACK_MAX_POINTS) -> dict[str, list[int]]:
    """En hızlı 'doğru' turun konum izinden pist çizgisini çıkarır."""
    laps = raw.laps.copy()
    laps["_lt"] = _seconds(laps["LapTime"])
    candidates = laps[laps["_lt"].notna()]
    if "IsAccurate" in candidates.columns:
        accurate = candidates[candidates["IsAccurate"].fillna(False).astype(bool)]
        if len(accurate):
            candidates = accurate
    # Hızlıdan yavaşa dene; konum verisi olan ilk turu kullan.
    for _, lap in candidates.sort_values("_lt").head(10).iterrows():
        pos = raw.pos.get(str(lap["DriverNumber"]))
        if pos is None or "X" not in pos.columns:
            continue
        t = _seconds(pos["SessionTime"])
        start = _seconds(pd.Series([lap["LapStartTime"]]))[0]
        end = _seconds(pd.Series([lap["Time"]]))[0]
        if np.isnan(start) or np.isnan(end):
            continue
        mask = (t >= start) & (t <= end)
        xs = pd.to_numeric(pos["X"], errors="coerce").to_numpy(dtype=float, na_value=np.nan)[mask]
        ys = pd.to_numeric(pos["Y"], errors="coerce").to_numpy(dtype=float, na_value=np.nan)[mask]
        good = ~(np.isnan(xs) | np.isnan(ys))
        xs, ys = xs[good], ys[good]
        if len(xs) < 50:
            continue
        step = max(1, len(xs) // max_points)
        xs, ys = xs[::step], ys[::step]
        xs = np.append(xs, xs[0])   # çizgiyi kapat
        ys = np.append(ys, ys[0])
        return {"x": [int(v) for v in np.rint(xs)], "y": [int(v) for v in np.rint(ys)]}
    raise IncompleteData("Pist çizgisi için konum verisi bulunamadı.")


def lap_starts(raw: RawSession, t0: float) -> tuple[list[float], int]:
    """Lider (kazanan) tur başlangıçları ve toplam tur sayısı."""
    laps = raw.laps
    total = int(pd.to_numeric(laps["LapNumber"], errors="coerce").max())
    winner = next((r["number"] for r in raw.results if r.get("position") == 1), None)
    if winner is None or not (laps["DriverNumber"].astype(str) == winner).any():
        counts = laps.groupby(laps["DriverNumber"].astype(str))["LapNumber"].max()
        winner = str(counts.idxmax())
    g = laps[laps["DriverNumber"].astype(str) == winner].sort_values("LapNumber")
    starts = _seconds(g["LapStartTime"]) - t0
    if len(starts) and np.isnan(starts[0]):
        starts[0] = 0.0
    starts = starts[~np.isnan(starts)]
    starts = np.maximum.accumulate(np.clip(starts, 0.0, None)) if len(starts) else starts
    return [round(float(s), 1) for s in starts], total


def build_payload(raw: RawSession, hz: int = DEFAULT_HZ) -> dict[str, Any]:
    t0, t1 = race_window(raw.laps)
    n = int(math.floor((t1 - t0) * hz)) + 1
    grid = t0 + np.arange(n) / hz

    codes = {r["number"]: r["code"] for r in raw.results}
    drivers: list[dict[str, Any]] = []
    for r in raw.results:
        pos = raw.pos.get(r["number"])
        if pos is None or len(pos) < 2:
            continue
        t_pos, pos_vals = _prepare(pos, ["X", "Y"])
        if "X" not in pos_vals or "Y" not in pos_vals:
            continue
        x = _linear(t_pos, pos_vals["X"], grid)
        y = _linear(t_pos, pos_vals["Y"], grid)
        if np.isnan(x).mean() > 0.99:
            continue
        item: dict[str, Any] = {
            "number": r["number"],
            "code": r["code"],
            "name": r["name"],
            "team": r["team"],
            "color": _color(r.get("color")),
            "position": r.get("position"),
            "x": _to_list(x),
            "y": _to_list(y),
        }
        car = raw.car.get(r["number"])
        if car is not None and len(car) >= 2:
            t_car, c = _prepare(car, ["Speed", "nGear", "Throttle", "Brake", "DRS"])
            if "Speed" in c:
                item["speed"] = _to_list(_linear(t_car, c["Speed"], grid))
            if "nGear" in c:
                item["gear"] = _to_list(_step(t_car, c["nGear"], grid))
            if "Throttle" in c:
                item["throttle"] = _to_list(np.clip(_linear(t_car, c["Throttle"], grid), 0, 100))
            if "Brake" in c:
                b = _step(t_car, c["Brake"], grid)
                item["brake"] = _to_list(np.where(np.isnan(b), np.nan, (b > 0).astype(float)))
            if "DRS" in c:
                d = _step(t_car, c["DRS"], grid)
                item["drs"] = _to_list(np.where(np.isnan(d), np.nan, (d >= DRS_OPEN_MIN).astype(float)))
        drivers.append(item)

    drivers.sort(key=lambda d: (d["position"] is None, d["position"] or 0, d["code"]))
    starts, total = lap_starts(raw, t0)
    return {
        "version": SCHEMA_VERSION,
        "event": {
            "year": raw.year,
            "round": raw.round,
            "session": raw.code,
            "name": raw.event_name,
            "country": raw.country,
            "circuit": raw.circuit,
        },
        "hz": hz,
        "duration": round(t1 - t0, 1),
        "totalLaps": total,
        "lapStarts": starts,
        "track": track_outline(raw),
        "drivers": drivers,
        "pits": extract_pits(raw.laps, codes, t0),
    }


def validate_payload(payload: dict[str, Any], min_drivers: int = 10,
                     min_coverage: float = 0.5, min_duration: float = 600.0) -> None:
    """Tamamlanmamış seansı 'hazır' saymamak için basit bütünlük kontrolü."""
    if payload["duration"] < min_duration:
        raise IncompleteData(f"Seans çok kısa ({payload['duration']} sn).")
    good = 0
    for d in payload["drivers"]:
        xs = d["x"]
        if xs and sum(v is not None for v in xs) / len(xs) >= min_coverage:
            good += 1
    if good < min_drivers:
        raise IncompleteData(f"Yeterli konum verisi olan pilot sayısı {good} (en az {min_drivers}).")


# --------------------------------------------------------------------------- dosya işleri

def encode(payload: dict[str, Any]) -> bytes:
    text = json.dumps(payload, separators=(",", ":"), ensure_ascii=False)
    return gzip.compress(text.encode("utf-8"), compresslevel=9, mtime=0)


def _atomic_write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=path.name, suffix=".tmp")
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(data)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def load_index(out_dir: Path) -> dict[str, Any]:
    path = out_dir / "index.json"
    if path.exists():
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(data, dict) and isinstance(data.get("sessions"), list):
                return data
        except json.JSONDecodeError:
            pass
    return {"version": SCHEMA_VERSION, "sessions": []}


def is_processed(index: dict[str, Any], year: int, rnd: int, code: str) -> bool:
    return any(s["year"] == year and s["round"] == rnd and s["session"] == code for s in index["sessions"])


def write_session(out_dir: Path, payload: dict[str, Any], now: Optional[datetime] = None) -> dict[str, Any]:
    ev = payload["event"]
    rel = f"{ev['year']}/r{ev['round']:02d}-{ev['session']}.json.gz"
    blob = encode(payload)
    _atomic_write(out_dir / rel, blob)

    entry = {
        "year": ev["year"], "round": ev["round"], "session": ev["session"],
        "name": ev["name"], "country": ev["country"], "circuit": ev["circuit"],
        "file": rel, "bytes": len(blob), "duration": payload["duration"], "hz": payload["hz"],
        "generatedAt": (now or datetime.now(timezone.utc)).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    index = load_index(out_dir)
    index["sessions"] = [s for s in index["sessions"]
                         if not (s["year"] == ev["year"] and s["round"] == ev["round"] and s["session"] == ev["session"])]
    index["sessions"].append(entry)
    index["sessions"].sort(key=lambda s: (s["year"], s["round"], s["session"]), reverse=True)
    index["version"] = SCHEMA_VERSION
    _atomic_write(out_dir / "index.json", (json.dumps(index, indent=2, ensure_ascii=False) + "\n").encode("utf-8"))
    return entry


def pending_races(schedule: list[dict[str, Any]], index: dict[str, Any], now: datetime,
                  settle: timedelta = timedelta(hours=3)) -> list[dict[str, Any]]:
    """Bitmiş (ve veri yayınlanması için beklenmiş) ama henüz işlenmemiş yarışlar, yeniden eskiye."""
    due = []
    for ev in schedule:
        end = ev.get("race_end_utc")
        if end is None or end + settle > now:
            continue
        if is_processed(index, ev["year"], ev["round"], "R"):
            continue
        due.append(ev)
    due.sort(key=lambda e: (e["year"], e["round"]), reverse=True)
    return due


# --------------------------------------------------------------------------- FastF1 katmanı

def load_raw(year: int, rnd: int, code: str = "R", cache_dir: str = ".fastf1-cache") -> RawSession:
    import fastf1  # tembel içe aktarma: saf fonksiyonlar FastF1 olmadan test edilebilsin

    Path(cache_dir).mkdir(parents=True, exist_ok=True)
    fastf1.Cache.enable_cache(cache_dir)
    session = fastf1.get_session(year, rnd, code)
    session.load(laps=True, telemetry=True, weather=False, messages=False)

    results = []
    for _, row in session.results.iterrows():
        position = row.get("Position")
        results.append({
            "number": _clean(row.get("DriverNumber")),
            "code": _clean(row.get("Abbreviation"), _clean(row.get("DriverNumber"))),
            "name": _clean(row.get("FullName")),
            "team": _clean(row.get("TeamName")),
            "color": _clean(row.get("TeamColor")),
            "position": None if position is None or pd.isna(position) else int(position),
        })

    lap_cols = ["DriverNumber", "LapNumber", "LapStartTime", "Time", "LapTime", "PitInTime", "PitOutTime", "IsAccurate"]
    laps = pd.DataFrame(session.laps)
    laps = laps[[c for c in lap_cols if c in laps.columns]].copy()
    laps["DriverNumber"] = laps["DriverNumber"].astype(str)

    car = {str(k): pd.DataFrame(v) for k, v in session.car_data.items()}
    pos = {str(k): pd.DataFrame(v) for k, v in session.pos_data.items()}
    event = session.event
    return RawSession(
        year=year, round=rnd, code=code,
        event_name=_clean(event.get("EventName"), f"Round {rnd}"),
        country=_clean(event.get("Country")),
        circuit=_clean(event.get("Location")),
        results=results, laps=laps, car=car, pos=pos,
    )


def fetch_schedule(year: int) -> list[dict[str, Any]]:
    import fastf1

    schedule = fastf1.get_event_schedule(year, include_testing=False)
    events = []
    for _, row in schedule.iterrows():
        end = row.get("Session5DateUtc")
        if end is None or pd.isna(end):
            end = None
        else:
            end = pd.Timestamp(end)
            end = (end.tz_localize("UTC") if end.tzinfo is None else end.tz_convert("UTC")).to_pydatetime()
        events.append({"year": year, "round": int(row["RoundNumber"]), "race_end_utc": end})
    return events


def process(year: int, rnd: int, code: str, out_dir: Path, hz: int, cache_dir: str) -> dict[str, Any]:
    raw = load_raw(year, rnd, code, cache_dir)
    payload = build_payload(raw, hz)
    validate_payload(payload, min_duration=600.0 if code == "R" else 300.0)
    return write_session(out_dir, payload)


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--year", type=int)
    parser.add_argument("--round", type=int)
    parser.add_argument("--session", default="R", choices=["R", "S"])
    parser.add_argument("--latest", action="store_true", help="Bitmiş ama işlenmemiş yarışları işle")
    parser.add_argument("--limit", type=int, default=2, help="--latest ile bir seferde en fazla kaç yarış")
    parser.add_argument("--hz", type=int, default=DEFAULT_HZ)
    parser.add_argument("--out", default="data/replay")
    parser.add_argument("--cache", default=".fastf1-cache")
    args = parser.parse_args(argv)
    out_dir = Path(args.out)

    if args.latest:
        now = datetime.now(timezone.utc)
        index = load_index(out_dir)
        todo = pending_races(fetch_schedule(now.year), index, now)[: args.limit]
        if not todo:
            print("İşlenecek yeni yarış yok.")
            return 0
        for ev in todo:
            try:
                entry = process(ev["year"], ev["round"], "R", out_dir, args.hz, args.cache)
                print(f"OK  {entry['name']} ({entry['bytes'] / 1024:.0f} KB)")
            except Exception as error:  # zamanlanmış çalışma sonraki turda yeniden dener
                print(f"::warning::{ev['year']} r{ev['round']} işlenemedi: {error}")
        return 0

    if args.year is None or args.round is None:
        parser.error("--latest ya da --year ve --round gerekli")
    try:
        entry = process(args.year, args.round, args.session, out_dir, args.hz, args.cache)
    except Exception as error:
        print(f"::error::{error}")
        return 1
    print(f"OK  {entry['name']} ({entry['bytes'] / 1024:.0f} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
