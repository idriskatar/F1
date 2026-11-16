"""Tamamen UYDURMA (sentetik) bir seans üretir: testler ve Flutter fixture'ı için.

Gerçek bir yarışla ilgisi yoktur; pilotlar/takımlar kurgusaldır.
Kullanım:  python tool/replay/sample_data.py test/fixtures/replay_sample.json
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_replay as br  # noqa: E402

RACE_START = 100.0   # oturum saniyesi
LAP_SECONDS = 20.0
LAPS = 3

DRIVERS = [
    ("1", "AAA", "Test Driver A", "Alpha Team", "3671C6", 1),
    ("2", "BBB", "Test Driver B", "Alpha Team", "3671C6", 2),
    ("3", "CCC", "Test Driver C", "Beta Team", "E80020", 3),
    ("4", "DDD", "Test Driver D", "Beta Team", "E80020", None),  # 2. turda yarıştan çekilir
]


def _td(seconds):
    return pd.to_timedelta(seconds, unit="s")


def synthetic_session(hz_source: float = 4.0) -> br.RawSession:
    results = [
        {"number": n, "code": c, "name": nm, "team": tm, "color": col, "position": pos}
        for n, c, nm, tm, col, pos in DRIVERS
    ]
    rows = []
    for number, *_ in DRIVERS:
        for lap in range(1, LAPS + 1):
            start = RACE_START + LAP_SECONDS * (lap - 1)
            pit_in = pit_out = pd.NaT
            if number == "2" and lap == 2:
                pit_in = _td(start + LAP_SECONDS - 2.0)     # 2. tur sonunda pite girer
            if number == "2" and lap == 3:
                pit_out = _td(start + 3.0)                  # 3. turda çıkar
            if number == "4" and lap == 3:
                continue                                    # çekilen pilotun 3. turu yok
            rows.append({
                "DriverNumber": number,
                "LapNumber": float(lap),
                "LapStartTime": _td(start),
                "Time": _td(start + LAP_SECONDS),
                "LapTime": _td(LAP_SECONDS + (0.3 if number == "3" else 0.0)),
                "PitInTime": pit_in,
                "PitOutTime": pit_out,
                "IsAccurate": lap != 1,
            })
    laps = pd.DataFrame(rows)

    t = np.arange(0.0, RACE_START + LAP_SECONDS * LAPS + 5.0, 1.0 / hz_source)
    car, pos = {}, {}
    for idx, (number, *_rest) in enumerate(DRIVERS):
        offset = idx * 0.4                                  # pilotlar arası küçük zaman farkı
        theta = 2 * math.pi * (t - RACE_START - offset) / LAP_SECONDS
        x = 3000 * np.cos(theta)
        y = 1800 * np.sin(theta)
        keep = np.ones_like(t, dtype=bool)
        if number == "4":
            keep &= t < RACE_START + 2 * LAP_SECONDS         # 40. saniyede veri biter
            keep &= ~((t > RACE_START + 12) & (t < RACE_START + 18))   # ortada veri boşluğu
        ts = t[keep]
        pos[number] = pd.DataFrame({"SessionTime": _td(ts), "X": x[keep], "Y": y[keep]})
        speed = 200 + 80 * np.sin(theta[keep] * 2)
        cycle = (np.arange(len(ts)) % 40)
        car[number] = pd.DataFrame({
            "SessionTime": _td(ts),
            "Speed": speed,
            "nGear": np.clip((speed // 50).astype(int), 1, 8),
            "Throttle": np.where(cycle < 25, 100.0, 15.0),
            "Brake": cycle >= 35,
            "DRS": np.where((cycle >= 10) & (cycle < 20), 12, 0),
        })
    return br.RawSession(
        year=2099, round=1, code="R",
        event_name="Test Grand Prix", country="Testland", circuit="Ovalville",
        results=results, laps=laps, car=car, pos=pos,
    )


if __name__ == "__main__":
    target = Path(sys.argv[1] if len(sys.argv) > 1 else "replay_sample.json")
    target.parent.mkdir(parents=True, exist_ok=True)
    payload = br.build_payload(synthetic_session(), hz=2)
    target.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
    print(f"yazıldı: {target} ({target.stat().st_size} bayt)")
