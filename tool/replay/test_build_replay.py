import json
import gzip
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_replay as br  # noqa: E402
import sample_data  # noqa: E402


class BuildPayloadTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = sample_data.synthetic_session()
        cls.payload = br.build_payload(cls.raw, hz=2)
        cls.by_code = {d["code"]: d for d in cls.payload["drivers"]}

    def test_window_and_lengths(self):
        self.assertEqual(br.race_window(self.raw.laps), (100.0, 160.0))
        self.assertEqual(self.payload["duration"], 60.0)
        self.assertEqual(self.payload["hz"], 2)
        n = 60 * 2 + 1
        for d in self.payload["drivers"]:
            for key in ("x", "y", "speed", "gear", "throttle", "brake", "drs"):
                self.assertEqual(len(d[key]), n, f"{d['code']}.{key}")

    def test_positions_are_exact_at_sample_times(self):
        a = self.by_code["AAA"]
        self.assertEqual(a["x"][0], 3000)          # theta = 0
        self.assertAlmostEqual(a["y"][10], 1800, delta=1)   # t=5 sn -> theta = pi/2
        self.assertAlmostEqual(a["x"][10], 0, delta=1)

    def test_driver_order_follows_final_position(self):
        self.assertEqual([d["code"] for d in self.payload["drivers"]], ["AAA", "BBB", "CCC", "DDD"])

    def test_missing_data_becomes_null_not_interpolated(self):
        d = self.by_code["DDD"]
        # Veri 40. saniyede biter (örnek 80), ortada 12-18. sn boşluğu var (örnek 24-36).
        self.assertIsNone(d["x"][100])
        self.assertIsNone(d["x"][30])
        self.assertIsNotNone(d["x"][10])
        self.assertIsNotNone(d["x"][60])

    def test_channels(self):
        a = self.by_code["AAA"]
        self.assertTrue(set(a["brake"]) <= {0, 1, None})
        self.assertTrue(set(a["drs"]) <= {0, 1, None})
        self.assertIn(1, a["drs"])
        self.assertTrue(all(0 <= v <= 100 for v in a["throttle"] if v is not None))
        self.assertTrue(all(1 <= v <= 8 for v in a["gear"] if v is not None))

    def test_pits(self):
        pits = self.payload["pits"]
        self.assertEqual(len(pits), 1)
        pit = pits[0]
        self.assertEqual(pit["driver"], "BBB")
        self.assertEqual(pit["lap"], 2)
        self.assertEqual(pit["in"], 38.0)      # 2. tur biter 40 sn, 2 sn önce giriş
        self.assertEqual(pit["out"], 43.0)     # 3. tur başlar 40 sn, +3 sn
        self.assertEqual(pit["pitLane"], 5.0)

    def test_lap_starts_and_total(self):
        self.assertEqual(self.payload["lapStarts"], [0.0, 20.0, 40.0])
        self.assertEqual(self.payload["totalLaps"], 3)

    def test_track_outline_is_closed_and_small(self):
        track = self.payload["track"]
        self.assertEqual(len(track["x"]), len(track["y"]))
        self.assertLessEqual(len(track["x"]), br.TRACK_MAX_POINTS + 2)
        self.assertEqual((track["x"][0], track["y"][0]), (track["x"][-1], track["y"][-1]))

    def test_validate(self):
        br.validate_payload(self.payload, min_drivers=3, min_duration=30)
        with self.assertRaises(br.IncompleteData):
            br.validate_payload(self.payload)                       # varsayılan eşikler: 10 pilot
        with self.assertRaises(br.IncompleteData):
            br.validate_payload(self.payload, min_drivers=3, min_duration=120)

    def test_incomplete_laps_raise(self):
        raw = sample_data.synthetic_session()
        raw.laps = raw.laps.assign(Time=np.nan).astype({"Time": "timedelta64[ns]"})
        with self.assertRaises(br.IncompleteData):
            br.build_payload(raw)

    def test_session_without_any_pit_stop(self):
        raw = sample_data.synthetic_session()
        raw.laps["PitInTime"] = pd.NaT       # tamamen NaT kolon (datetime türüne düşebilir)
        raw.laps["PitOutTime"] = pd.NaT
        payload = br.build_payload(raw, hz=2)
        self.assertEqual(payload["pits"], [])

    def test_json_roundtrip_has_no_nan(self):
        text = json.dumps(self.payload, allow_nan=False)    # NaN olsaydı hata verirdi
        self.assertEqual(json.loads(text)["version"], br.SCHEMA_VERSION)


class FilesTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.out = Path(self.tmp.name)
        self.payload = br.build_payload(sample_data.synthetic_session(), hz=2)

    def tearDown(self):
        self.tmp.cleanup()

    def test_encode_is_deterministic_and_gzip(self):
        a, b = br.encode(self.payload), br.encode(self.payload)
        self.assertEqual(a, b)
        self.assertEqual(json.loads(gzip.decompress(a))["event"]["name"], "Test Grand Prix")

    def test_write_session_updates_index_without_duplicates(self):
        now = datetime(2026, 11, 15, 12, 0, tzinfo=timezone.utc)
        entry = br.write_session(self.out, self.payload, now)
        br.write_session(self.out, self.payload, now)             # tekrar: yinelenmemeli
        index = br.load_index(self.out)
        self.assertEqual(len(index["sessions"]), 1)
        self.assertEqual(index["sessions"][0]["file"], "2099/r01-R.json.gz")
        self.assertEqual(entry["generatedAt"], "2026-11-15T12:00:00Z")
        self.assertTrue((self.out / entry["file"]).exists())
        self.assertTrue(br.is_processed(index, 2099, 1, "R"))
        self.assertFalse(br.is_processed(index, 2099, 2, "R"))

    def test_index_is_sorted_newest_first(self):
        for rnd in (3, 1, 2):
            payload = json.loads(json.dumps(self.payload))
            payload["event"]["round"] = rnd
            br.write_session(self.out, payload)
        self.assertEqual([s["round"] for s in br.load_index(self.out)["sessions"]], [3, 2, 1])

    def test_corrupt_index_is_replaced(self):
        (self.out / "index.json").write_text("{bozuk", encoding="utf-8")
        self.assertEqual(br.load_index(self.out)["sessions"], [])


class PendingTest(unittest.TestCase):
    def test_pending_races(self):
        now = datetime(2026, 11, 15, 20, 0, tzinfo=timezone.utc)
        schedule = [
            {"year": 2026, "round": 20, "race_end_utc": now - timedelta(days=14)},
            {"year": 2026, "round": 21, "race_end_utc": now - timedelta(days=7)},
            {"year": 2026, "round": 22, "race_end_utc": now - timedelta(hours=1)},   # henüz erken
            {"year": 2026, "round": 23, "race_end_utc": now + timedelta(days=7)},    # gelecek
            {"year": 2026, "round": 24, "race_end_utc": None},
        ]
        index = {"version": 1, "sessions": [{"year": 2026, "round": 20, "session": "R"}]}
        due = br.pending_races(schedule, index, now)
        self.assertEqual([e["round"] for e in due], [21])


if __name__ == "__main__":
    unittest.main()
