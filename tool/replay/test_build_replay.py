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


class NewFieldsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = sample_data.synthetic_session()
        cls.payload = br.build_payload(cls.raw, hz=2)
        cls.by_code = {d["code"]: d for d in cls.payload["drivers"]}

    def test_rpm_channel(self):
        a = self.by_code["AAA"]
        self.assertEqual(len(a["rpm"]), 121)
        self.assertTrue(all(6000 <= v <= 12000 for v in a["rpm"] if v is not None))

    def test_last_name(self):
        self.assertEqual(self.by_code["AAA"]["lastName"], "Alpha")

    def test_position_log_is_relative_and_compact(self):
        self.assertEqual(self.by_code["AAA"]["positionLog"], [[0.0, 1]])
        self.assertEqual(self.by_code["BBB"]["positionLog"], [[0.0, 2], [30.0, 3]])
        self.assertEqual(self.by_code["CCC"]["positionLog"], [[0.0, 3], [30.0, 2]])

    def test_position_log_drops_repeats_and_keeps_state_at_start(self):
        raw = sample_data.synthetic_session()
        raw.position_log = {"1": [(90.0, 5), (95.0, 4), (100.0, 4), (110.0, 4), (120.0, 3), (121.0, 3)]}
        # t0 = 100: 100'deki sıra (4) başlangıç durumu olur, tekrarlar atılır.
        self.assertEqual(br.position_log_for(raw, "1", 100.0), [[0.0, 4], [20.0, 3]])
        self.assertEqual(br.position_log_for(raw, "9", 100.0), [])

    def test_laps_table(self):
        a = self.by_code["AAA"]["laps"]
        self.assertEqual(a[0], [1, 0.0, 20.0, None, 8.0, 6.0])      # 1. tur: S1 boş
        self.assertEqual(a[1], [2, 20.0, 20.0, 5.5, 8.0, 6.5])
        self.assertEqual(len(a), 3)
        self.assertEqual(len(self.by_code["DDD"]["laps"]), 2)        # çekilen pilotun 3. turu yok
        self.assertEqual(self.by_code["CCC"]["laps"][2][2], 20.3)

    def test_lap_one_start_defaults_to_race_start_when_missing(self):
        raw = sample_data.synthetic_session()
        raw.laps.loc[(raw.laps["DriverNumber"] == "1") & (raw.laps["LapNumber"] == 1), "LapStartTime"] = pd.NaT
        table = br.laps_table(raw.laps, "1", 100.0)
        self.assertEqual(table[0][1], 0.0)            # başkalarının 1. tur başlangıcı biliniyor
        raw.laps["LapStartTime"] = raw.laps["LapStartTime"].where(raw.laps["LapNumber"] != 1, pd.NaT)
        self.assertIsNone(br.laps_table(raw.laps, "1", 100.0)[0][1])   # kimse bilmiyorsa null

    def test_stints(self):
        self.assertEqual(self.by_code["BBB"]["stints"], [["MEDIUM", 1, 2, 0], ["HARD", 3, None, 0]])
        self.assertEqual(self.by_code["CCC"]["stints"], [["HARD", 1, None, 2]])

    def test_old_style_input_has_no_new_keys(self):
        raw = sample_data.synthetic_session()
        raw.position_log = None
        raw.stints = None
        raw.laps = raw.laps.drop(columns=["S1", "S2", "S3"])
        raw.car = {k: v.drop(columns=["RPM"]) for k, v in raw.car.items()}
        d = br.build_payload(raw, hz=2)["drivers"][0]
        for key in ("positionLog", "stints", "rpm"):
            self.assertNotIn(key, d)
        self.assertEqual(d["laps"][1][3:], [None, None, None])       # sektör bilgisi yok -> null


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
