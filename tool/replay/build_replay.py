#!/usr/bin/env python3
# OpenF1 API verisinden F1 Tracker için küçük, sıkıştırılmış replay dosyaları üretir.
# Çıktı (varsayılan: data/replay/):
#   index.json -> hazır seansların listesi
#   <yıl>/r<tur>-<seans>.json.gz -> tek bir seansın replay verisi (şema v1)

from __future__ import annotations

import argparse
import gzip
import json
import math
import os
import sys
import tempfile
import time
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Optional

import numpy as np
import pandas as pd

SCHEMA_VERSION = 1
DEFAULT_HZ = 2
MAX_GAP_SECONDS = 3.0      # kaynak örnekler arasında bundan büyük boşluk -> veri yok (null)
DRS_OPEN_MIN = 10          # F1 DRS kodu: 10/12/14 = açık, 8 = açılabilir, 0/1 = kapalı
TRACK_MAX_POINTS = 400
FALLBACK_COLOR = "#9AA0A6"
OPENF1_BASE_URL = "https://api.openf1.org/v1"


class IncompleteData(RuntimeError):
    """Kaynak henüz tam yayınlanmamış ya da veri kalitesi yetersiz."""


@dataclass
class RawSession:
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
    pits_override: Optional[list[dict[str, Any]]] = None
    # pilot no -> [(oturum saniyesi, sıra), ...]  (OpenF1 'position' ucu)
    position_log: Optional[dict[str, list[tuple[float, int]]]] = None
    # pilot no -> [{'compound', 'lap_start', 'lap_end', 'age'}, ...]  (OpenF1 'stints' ucu)
    stints: Optional[dict[str, list[dict[str, Any]]]] = None
    # [{'ts': oturum sn, 'air', 'track', 'humidity', 'wind' (km/sa), 'wind_dir', 'rain'}, ...]  (OpenF1 'weather' ucu)
    weather: Optional[list[dict[str, Any]]] = None


# --------------------------------------------------------------------------- yardımcılar

def _seconds(series: pd.Series) -> np.ndarray:
    if pd.api.types.is_datetime64_any_dtype(series):
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
    t = _seconds(df["SessionTime"])
    keep = ~np.isnan(t)
    t = t[keep]
    order = np.argsort(t)
    t = t[order]
    uniq, first = np.unique(t, return_index=True)
    values = {}
    for col in columns:
        if col in df.columns:
            raw = pd.to_numeric(df[col], errors="coerce")
            values[col] = raw.to_numpy(dtype=float, na_value=np.nan)[keep][order][first]
    return uniq, values


def _coverage(t_src: np.ndarray, grid: np.ndarray, max_gap: float) -> tuple[np.ndarray, np.ndarray]:
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
    starts = _seconds(laps["LapStartTime"])
    lap_no = pd.to_numeric(laps["LapNumber"], errors="coerce").to_numpy(dtype=float, na_value=np.nan)
    first = starts[(lap_no == 1) & ~np.isnan(starts)]
    if len(first):
        t0 = float(first.min())
    elif np.any(~np.isnan(starts)):
        t0 = float(np.nanmin(starts))
    else:
        raise IncompleteData("Tur baslangic zamanlari yok.")
    ends = _seconds(laps["Time"])
    if not np.any(~np.isnan(ends)):
        raise IncompleteData("Tur bitis zamanlari yok.")
    t1 = float(np.nanmax(ends))
    if t1 <= t0:
        raise IncompleteData("Yaris penceresi gecersiz.")
    return t0, t1


def extract_pits(laps: pd.DataFrame, codes: dict[str, str], t0: float) -> list[dict[str, Any]]:
    pits: list[dict[str, Any]] = []
    if "PitInTime" not in laps.columns or "PitOutTime" not in laps.columns:
        return pits
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
    laps = raw.laps.copy()
    laps["_lt"] = _seconds(laps["LapTime"])
    candidates = laps[laps["_lt"].notna() & (laps["_lt"] > 0)]
    if "IsAccurate" in candidates.columns:
        accurate = candidates[candidates["IsAccurate"].fillna(False).astype(bool)]
        if len(accurate):
            candidates = accurate

    for _, lap in candidates.sort_values("_lt").head(40).iterrows():
        pos = raw.pos.get(str(lap["DriverNumber"]))
        if pos is None or "X" not in pos.columns or "Y" not in pos.columns:
            continue
        t = _seconds(pos["SessionTime"])
        start = _seconds(pd.Series([lap["LapStartTime"]]))[0]
        end = _seconds(pd.Series([lap["Time"]]))[0]
        if np.isnan(start) or np.isnan(end):
            continue
        mask = (t >= start) & (t <= end)
        xs = pd.to_numeric(pos["X"], errors="coerce").to_numpy(dtype=float, na_value=np.nan)[mask]
        ys = pd.to_numeric(pos["Y"], errors="coerce").to_numpy(dtype=float, na_value=np.nan)[mask]
        valid = ~(np.isnan(xs) | np.isnan(ys)) & ((np.abs(xs) > 1e-6) | (np.abs(ys) > 1e-6))
        xs, ys = xs[valid], ys[valid]
        if len(xs) < 20:
            continue
        step = max(1, len(xs) // max_points)
        xs, ys = xs[::step], ys[::step]
        xs = np.append(xs, xs[0])
        ys = np.append(ys, ys[0])
        return {"x": [int(v) for v in np.rint(xs)], "y": [int(v) for v in np.rint(ys)]}

    # Yedek: aday tur penceresinde bulunamazsa seanstaki gecerli (0, 0) disi konumlardan cikar
    for _, pos in raw.pos.items():
        if pos is None or "X" not in pos.columns or "Y" not in pos.columns:
            continue
        xs = pd.to_numeric(pos["X"], errors="coerce").to_numpy(dtype=float, na_value=np.nan)
        ys = pd.to_numeric(pos["Y"], errors="coerce").to_numpy(dtype=float, na_value=np.nan)
        valid = ~(np.isnan(xs) | np.isnan(ys)) & ((np.abs(xs) > 1e-6) | (np.abs(ys) > 1e-6))
        xs, ys = xs[valid], ys[valid]
        if len(xs) >= 50:
            step = max(1, len(xs) // max_points)
            xs, ys = xs[::step], ys[::step]
            xs = np.append(xs, xs[0])
            ys = np.append(ys, ys[0])
            return {"x": [int(v) for v in np.rint(xs)], "y": [int(v) for v in np.rint(ys)]}

    raise IncompleteData("Pist cizgisi icin konum verisi bulunamadi.")


def lap_starts(raw: RawSession, t0: float) -> tuple[list[float], int]:
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


def position_log_for(raw: RawSession, number: str, t0: float) -> list[list[Any]]:
    """Sıra değişimleri: [[replay_sn, sıra], ...]. t0 anındaki sıra 0. saniyeye taşınır."""
    events = sorted((raw.position_log or {}).get(number) or [], key=lambda e: e[0])
    initial = None
    rest: list[tuple[float, int]] = []
    for ts, pos in events:
        if ts <= t0:
            initial = int(pos)
        else:
            rest.append((ts - t0, int(pos)))
    out: list[list[Any]] = []
    if initial is not None:
        out.append([0.0, initial])
    for rel, pos in rest:
        if out and out[-1][1] == pos:
            continue                      # arka arkaya aynı sıra: gereksiz
        out.append([round(rel, 1), pos])
    return out


def laps_table(laps: pd.DataFrame, number: str, t0: float) -> list[list[Any]]:
    """[[tur, başlangıç_sn, süre, s1, s2, s3], ...]; bilinmeyenler null. Süreler saniye."""
    g = laps[laps["DriverNumber"].astype(str) == number].sort_values("LapNumber")
    if g.empty:
        return []
    nums = pd.to_numeric(g["LapNumber"], errors="coerce").to_numpy(dtype=float, na_value=np.nan)
    starts = _seconds(g["LapStartTime"]) - t0
    durations = _seconds(g["LapTime"])
    sectors = [
        pd.to_numeric(g[c], errors="coerce").to_numpy(dtype=float, na_value=np.nan)
        if c in g.columns else np.full(len(g), np.nan)
        for c in ("S1", "S2", "S3")
    ]
    # OpenF1'de 1. turun date_start değeri sık sık boştur. t0 zaten 1. tur başlangıcından
    # hesaplandıysa, eksik 1. tur başlangıcı yarış başlangıcıdır (0. saniye).
    all_nums = pd.to_numeric(laps["LapNumber"], errors="coerce").to_numpy(dtype=float, na_value=np.nan)
    all_starts = _seconds(laps["LapStartTime"])
    lap1_known = bool(np.any((all_nums == 1) & ~np.isnan(all_starts)))

    def rnd(value: float, digits: int) -> Optional[float]:
        return None if math.isnan(value) else round(float(value), digits)

    rows: list[list[Any]] = []
    for i in range(len(g)):
        if math.isnan(nums[i]):
            continue
        start = starts[i]
        if math.isnan(start) and nums[i] == 1 and lap1_known:
            start = 0.0
        rows.append([int(nums[i]), rnd(start, 2), rnd(durations[i], 3),
                     rnd(sectors[0][i], 3), rnd(sectors[1][i], 3), rnd(sectors[2][i], 3)])
    return rows


def weather_rows(raw: RawSession, t0: float) -> list[list[Any]]:
    """[[replay_sn, hava, pist, nem, rüzgâr_km/sa, rüzgâr_yönü, yağmur(0/1)], ...]
    t0 anındaki (ya da ondan önceki son) ölçüm 0. saniyeye taşınır; bilinmeyenler null."""
    items = sorted(raw.weather or [], key=lambda r: r["ts"])
    initial = None
    rest = []
    for item in items:
        if item["ts"] <= t0:
            initial = item
        else:
            rest.append(item)

    def num(value: Any, digits: int) -> Optional[float]:
        if value is None or (isinstance(value, float) and math.isnan(value)):
            return None
        return int(round(float(value))) if digits == 0 else round(float(value), digits)

    def pack(rel: float, item: dict[str, Any]) -> list[Any]:
        rain = item.get("rain")
        return [round(rel, 1), num(item.get("air"), 1), num(item.get("track"), 1), num(item.get("humidity"), 0),
                num(item.get("wind"), 1), num(item.get("wind_dir"), 0),
                None if rain is None or (isinstance(rain, float) and math.isnan(rain)) else (1 if rain else 0)]

    out: list[list[Any]] = []
    if initial is not None:
        out.append(pack(0.0, initial))
    out.extend(pack(item["ts"] - t0, item) for item in rest)
    return out


def stints_for(raw: RawSession, number: str) -> list[list[Any]]:
    """[[bileşen, ilk_tur, son_tur|null, başlangıç_yaşı], ...]"""
    items = sorted((raw.stints or {}).get(number) or [], key=lambda s: s["lap_start"])
    return [[s["compound"], s["lap_start"], s["lap_end"], s["age"]] for s in items]


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
        if r.get("last_name"):
            item["lastName"] = r["last_name"]
        car = raw.car.get(r["number"])
        if car is not None and len(car) >= 2:
            t_car, c = _prepare(car, ["Speed", "nGear", "Throttle", "Brake", "DRS", "RPM"])
            if "Speed" in c:
                item["speed"] = _to_list(_linear(t_car, c["Speed"], grid))
            if "RPM" in c:
                item["rpm"] = _to_list(_linear(t_car, c["RPM"], grid))
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
        log = position_log_for(raw, r["number"], t0)
        if log:
            item["positionLog"] = log
        table = laps_table(raw.laps, r["number"], t0)
        if table:
            item["laps"] = table
        stint_rows = stints_for(raw, r["number"])
        if stint_rows:
            item["stints"] = stint_rows
        drivers.append(item)

    drivers.sort(key=lambda d: (d["position"] is None, d["position"] or 0, d["code"]))
    starts, total = lap_starts(raw, t0)

    if raw.pits_override is not None:
        pits = [
            {
                "driver": p["driver"],
                "lap": p["lap"],
                "in": round(p["abs_in"] - t0, 1),
                "out": None if p["abs_out"] is None else round(p["abs_out"] - t0, 1),
                "pitLane": p["pit_lane"],
            }
            for p in raw.pits_override
            if p["abs_in"] >= t0
        ]
        pits.sort(key=lambda p: (p["in"], p["driver"]))
    else:
        pits = extract_pits(raw.laps, codes, t0)

    weather = weather_rows(raw, t0)
    payload: dict[str, Any] = {
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
        "pits": pits,
    }
    if weather:
        payload["weather"] = weather
    return payload


def validate_payload(payload: dict[str, Any], min_drivers: int = 10,
                     min_coverage: float = 0.5, min_duration: float = 600.0) -> None:
    if payload["duration"] < min_duration:
        raise IncompleteData(f"Seans cok kisa ({payload['duration']} sn).")
    good = 0
    for d in payload["drivers"]:
        xs = d["x"]
        if xs and sum(v is not None for v in xs) / len(xs) >= min_coverage:
            good += 1
    if good < min_drivers:
        raise IncompleteData(f"Yeterli konum verisi olan pilot sayisi {good} (en az {min_drivers}).")


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


# --------------------------------------------------------------------------- OpenF1 API katmanı

def _openf1_get(endpoint: str, params: dict[str, Any], retries: int = 4) -> list[dict[str, Any]]:
    import requests

    url = f"{OPENF1_BASE_URL}/{endpoint}"
    for attempt in range(retries):
        resp = requests.get(url, params=params, timeout=60)
        if resp.status_code == 200:
            data = resp.json()
            return data if isinstance(data, list) else []
        if resp.status_code in (429, 500, 502, 503, 504):
            time.sleep(2.0 * (attempt + 1))
            continue
        if resp.status_code == 404:
            return []
        resp.raise_for_status()
    raise IncompleteData(f"OpenF1 '{endpoint}' istegi zaman asimina ugradi.")


def _optional_get(endpoint: str, params: dict[str, Any]) -> list[dict[str, Any]]:
    """Replay için zorunlu olmayan uçlar: hata tüm seansı düşürmesin, uyarı verip boş dönsün."""
    try:
        return _openf1_get(endpoint, params)
    except Exception as error:
        print(f"::warning::OpenF1 '{endpoint}' alinamadi, atlaniyor: {error}")
        return []


def _parse_iso(ts: Any) -> Optional[datetime]:
    if not ts:
        return None
    dt = pd.to_datetime(ts, utc=True, errors="coerce", format="ISO8601")
    if pd.isna(dt):
        return None
    return dt.to_pydatetime()


def _is_cancelled(session: dict[str, Any]) -> bool:
    val = session.get("is_cancelled")
    if isinstance(val, bool):
        return val
    if isinstance(val, (int, float)):
        return bool(val)
    if isinstance(val, str):
        return val.strip().lower() in ("true", "1", "yes")
    return False


def _resolve_session(year: int, rnd: int, code: str) -> dict[str, Any]:
    sessions = _openf1_get("sessions", {"year": year})
    if not sessions:
        raise IncompleteData(f"{year} sezonu icin OpenF1 seans listesi bulunamadi.")

    race_meetings: dict[int, datetime] = {}
    for s in sessions:
        if _is_cancelled(s):
            continue
        sname = _clean(s.get("session_name")).lower()
        stype = _clean(s.get("session_type")).lower()
        if "testing" in sname or ("practice" in sname and "testing" in _clean(s.get("meeting_name")).lower()):
            continue
        if stype == "race":
            mk = s.get("meeting_key")
            dt = _parse_iso(s.get("date_start"))
            if mk is not None and dt is not None:
                if mk not in race_meetings or dt < race_meetings[mk]:
                    race_meetings[mk] = dt

    ordered_meetings = [mk for mk, _ in sorted(race_meetings.items(), key=lambda x: x[1])]
    if rnd < 1 or rnd > len(ordered_meetings):
        raise IncompleteData(f"{year} sezonunda {rnd}. tur bulunamadi (toplam {len(ordered_meetings)} tur).")

    target_mk = ordered_meetings[rnd - 1]
    target_name = "Sprint" if code.upper() == "S" else "Race"

    for s in sessions:
        if _is_cancelled(s):
            continue
        if s.get("meeting_key") == target_mk and _clean(s.get("session_name")).lower() == target_name.lower():
            return s

    raise IncompleteData(f"{year} r{rnd} icin '{target_name}' seansi bulunamadi.")


def load_raw(year: int, rnd: int, code: str = "R", cache_dir: str = ".fastf1-cache") -> RawSession:
    session_info = _resolve_session(year, rnd, code)
    session_key = session_info["session_key"]
    session_start = _parse_iso(session_info.get("date_start"))
    if session_start is None:
        raise IncompleteData("Seans baslangic zamani eksik.")

    def to_rel_td(iso_series: pd.Series) -> pd.Series:
        # format="ISO8601": kesirli saniyesi olan/olmayan damgalar aynı sütunda karışık olabilir;
        # biçim ilk satırdan çıkarılırsa uymayanlar sessizce NaT olur.
        dt = pd.to_datetime(iso_series, utc=True, errors="coerce", format="ISO8601")
        return dt - pd.Timestamp(session_start)

    drivers_raw = _openf1_get("drivers", {"session_key": session_key})
    if not drivers_raw:
        raise IncompleteData("Pilot listesi henüz yayinlanmadi.")

    results_raw = _openf1_get("session_result", {"session_key": session_key})
    pos_map = {str(r["driver_number"]): r.get("position") for r in results_raw if r.get("driver_number") is not None}

    results: list[dict[str, Any]] = []
    seen_nums: set[str] = set()
    for d in drivers_raw:
        num = _clean(d.get("driver_number"))
        if not num or num in seen_nums:
            continue
        seen_nums.add(num)
        pos_val = pos_map.get(num)
        results.append({
            "number": num,
            "code": _clean(d.get("name_acronym"), num),
            "name": _clean(d.get("full_name") or d.get("broadcast_name"), num),
            "last_name": _clean(d.get("last_name")),
            "team": _clean(d.get("team_name")),
            "color": _clean(d.get("team_colour")),
            "position": None if pos_val is None or pd.isna(pos_val) else int(pos_val),
        })

    codes = {r["number"]: r["code"] for r in results}

    laps_raw = _openf1_get("laps", {"session_key": session_key})
    if not laps_raw:
        raise IncompleteData("Tur verileri henüz yayinlanmadi.")

    laps_df = pd.DataFrame(laps_raw)
    laps_df["DriverNumber"] = laps_df["driver_number"].astype(str)
    laps_df["LapNumber"] = pd.to_numeric(laps_df["lap_number"], errors="coerce")
    laps_df["LapStartTime"] = to_rel_td(laps_df["date_start"])
    laps_df["LapTime"] = pd.to_timedelta(pd.to_numeric(laps_df["lap_duration"], errors="coerce"), unit="s")
    for src, dst in (("duration_sector_1", "S1"), ("duration_sector_2", "S2"), ("duration_sector_3", "S3")):
        laps_df[dst] = pd.to_numeric(laps_df[src], errors="coerce") if src in laps_df.columns else np.nan
    laps_df["Time"] = laps_df["LapStartTime"] + laps_df["LapTime"]
    if "is_pit_out_lap" in laps_df.columns:
        laps_df["IsAccurate"] = ~laps_df["is_pit_out_lap"].fillna(False).astype(bool)
    else:
        laps_df["IsAccurate"] = True

    laps_df = laps_df.sort_values(["DriverNumber", "LapNumber"]).reset_index(drop=True)
    next_start = laps_df.groupby("DriverNumber")["LapStartTime"].shift(-1)
    laps_df["Time"] = laps_df["Time"].fillna(next_start)

    pits_raw = _openf1_get("pit", {"session_key": session_key})
    pits_override: list[dict[str, Any]] = []
    for p in pits_raw:
        num = _clean(p.get("driver_number"))
        if num not in codes:
            continue
        dt_pit = _parse_iso(p.get("date"))
        if dt_pit is None:
            continue
        abs_in = (dt_pit - session_start).total_seconds()
        dur = p.get("pit_duration")
        pit_lane = round(float(dur), 1) if dur is not None and not pd.isna(dur) else None
        abs_out = (abs_in + pit_lane) if pit_lane is not None else None
        pits_override.append({
            "driver": codes[num],
            "lap": int(p.get("lap_number") or 0),
            "abs_in": abs_in,
            "abs_out": abs_out,
            "pit_lane": pit_lane,
        })

    position_log: dict[str, list[tuple[float, int]]] = {}
    for row in _optional_get("position", {"session_key": session_key}):
        num = _clean(row.get("driver_number"))
        when = _parse_iso(row.get("date"))
        place = row.get("position")
        if num not in codes or when is None or place is None or pd.isna(place):
            continue
        position_log.setdefault(num, []).append(((when - session_start).total_seconds(), int(place)))

    stints: dict[str, list[dict[str, Any]]] = {}
    for row in _optional_get("stints", {"session_key": session_key}):
        num = _clean(row.get("driver_number"))
        first = row.get("lap_start")
        if num not in codes or first is None or pd.isna(first):
            continue
        last = row.get("lap_end")
        age = row.get("tyre_age_at_start")
        stints.setdefault(num, []).append({
            "compound": _clean(row.get("compound"), "UNKNOWN").upper(),
            "lap_start": int(first),
            "lap_end": None if last is None or pd.isna(last) else int(last),
            "age": 0 if age is None or pd.isna(age) else int(age),
        })

    weather: list[dict[str, Any]] = []
    for row in _optional_get("weather", {"session_key": session_key}):
        when = _parse_iso(row.get("date"))
        if when is None:
            continue

        def reading(key: str, row: dict[str, Any] = row) -> Optional[float]:
            value = row.get(key)
            return None if value is None or pd.isna(value) else float(value)

        wind_ms = reading("wind_speed")           # OpenF1: m/s -> km/sa
        weather.append({
            "ts": (when - session_start).total_seconds(),
            "air": reading("air_temperature"),
            "track": reading("track_temperature"),
            "humidity": reading("humidity"),
            "wind": None if wind_ms is None else wind_ms * 3.6,
            "wind_dir": reading("wind_direction"),
            "rain": reading("rainfall"),
        })

    car: dict[str, pd.DataFrame] = {}
    pos: dict[str, pd.DataFrame] = {}

    for r in results:
        num = r["number"]
        loc_rows = _openf1_get("location", {"session_key": session_key, "driver_number": int(num)})
        if loc_rows:
            df_loc = pd.DataFrame(loc_rows)
            df_loc["SessionTime"] = to_rel_td(df_loc["date"])
            df_loc["X"] = pd.to_numeric(df_loc["x"], errors="coerce")
            df_loc["Y"] = pd.to_numeric(df_loc["y"], errors="coerce")
            pos[num] = df_loc[["SessionTime", "X", "Y"]]

        car_rows = _openf1_get("car_data", {"session_key": session_key, "driver_number": int(num)})
        if car_rows:
            df_car = pd.DataFrame(car_rows)
            df_car["SessionTime"] = to_rel_td(df_car["date"])
            df_car["Speed"] = pd.to_numeric(df_car.get("speed"), errors="coerce")
            df_car["nGear"] = pd.to_numeric(df_car.get("n_gear"), errors="coerce")
            df_car["Throttle"] = pd.to_numeric(df_car.get("throttle"), errors="coerce")
            df_car["Brake"] = pd.to_numeric(df_car.get("brake"), errors="coerce")
            df_car["DRS"] = pd.to_numeric(df_car.get("drs"), errors="coerce")
            df_car["RPM"] = pd.to_numeric(df_car.get("rpm"), errors="coerce")
            car[num] = df_car[["SessionTime", "Speed", "nGear", "Throttle", "Brake", "DRS", "RPM"]]

        time.sleep(0.1)

    event_name = _clean(session_info.get("meeting_name") or session_info.get("country_name"), f"Round {rnd}")
    return RawSession(
        year=year,
        round=rnd,
        code=code.upper(),
        event_name=event_name,
        country=_clean(session_info.get("country_name")),
        circuit=_clean(session_info.get("circuit_short_name") or session_info.get("location")),
        results=results,
        laps=laps_df,
        car=car,
        pos=pos,
        pits_override=pits_override,
        position_log=position_log,
        stints=stints,
        weather=weather,
    )


def fetch_schedule(year: int) -> list[dict[str, Any]]:
    sessions = _openf1_get("sessions", {"year": year})
    races = []
    for s in sessions:
        if _is_cancelled(s):
            continue
        if _clean(s.get("session_name")).lower() == "race":
            dt_start = _parse_iso(s.get("date_start"))
            dt_end = _parse_iso(s.get("date_end"))
            if dt_start is not None:
                races.append((dt_start, dt_end))

    races.sort(key=lambda x: x[0])
    events = []
    for idx, (dt_start, dt_end) in enumerate(races, start=1):
        events.append({"year": year, "round": idx, "race_end_utc": dt_end})
    return events


def process(year: int, rnd: int, code: str, out_dir: Path, hz: int, cache_dir: str,
            expect_name: Optional[str] = None) -> dict[str, Any]:
    raw = load_raw(year, rnd, code, cache_dir)
    payload = build_payload(raw, hz)
    if expect_name and payload["event"]["name"] != expect_name:
        # Yenilemede OpenF1 sıralaması kaymışsa yanlış yarışın üzerine yazmayalım.
        raise IncompleteData(f"yaris adi uyusmuyor ('{expect_name}' beklenirken '{payload['event']['name']}' geldi)")
    validate_payload(payload, min_duration=600.0 if code == "R" else 300.0)
    return write_session(out_dir, payload)


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="OpenF1 Replay Builder")
    parser.add_argument("--year", type=int)
    parser.add_argument("--round", type=int)
    parser.add_argument("--session", default="R", choices=["R", "S"])
    parser.add_argument("--latest", action="store_true")
    parser.add_argument("--limit", type=int, default=None, help="--latest: en fazla kaç yarış (varsayılan 2); --refresh: en fazla kaç dosya (varsayılan hepsi)")
    parser.add_argument("--refresh", action="store_true", help="index.json'daki tüm seansları yeniden üret (yeni alanlar için)")
    parser.add_argument("--hz", type=int, default=DEFAULT_HZ)
    parser.add_argument("--out", default="data/replay")
    parser.add_argument("--cache", default=".fastf1-cache")
    args = parser.parse_args(argv)
    out_dir = Path(args.out)

    if args.refresh:
        entries = list(load_index(out_dir)["sessions"])
        if args.limit:
            entries = entries[: args.limit]
        ok = failed = 0
        for e in entries:
            try:
                entry = process(e["year"], e["round"], e.get("session", "R"), out_dir, args.hz, args.cache,
                                expect_name=e.get("name"))
                print(f"OK  {entry['name']} yenilendi ({entry['bytes'] / 1024:.0f} KB)")
                ok += 1
            except Exception as error:
                print(f"::warning::{e['year']} r{e['round']} yenilenemedi (eski dosya korunuyor): {error}")
                failed += 1
        print(f"Yenileme tamam: {ok} basarili, {failed} basarisiz.")
        return 1 if entries and ok == 0 else 0

    if args.latest:
        now = datetime.now(timezone.utc)
        index = load_index(out_dir)
        todo = pending_races(fetch_schedule(now.year), index, now)[: (args.limit or 2)]
        if not todo:
            print("Islenecek yeni yaris yok.")
            return 0
        for ev in todo:
            try:
                entry = process(ev["year"], ev["round"], "R", out_dir, args.hz, args.cache)
                print(f"OK  {entry['name']} ({entry['bytes'] / 1024:.0f} KB)")
            except Exception as error:
                print(f"::warning::{ev['year']} r{ev['round']} islenemedi: {error}")
        return 0

    if args.year is None or args.round is None:
        parser.error("--latest, --refresh ya da --year ve --round gerekli")
    try:
        entry = process(args.year, args.round, args.session, out_dir, args.hz, args.cache)
    except Exception as error:
        print(f"::error::{error}")
        return 1
    print(f"OK  {entry['name']} ({entry['bytes'] / 1024:.0f} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
