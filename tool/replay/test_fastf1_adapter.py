# OpenF1 adapter testleri (load_raw, fetch_schedule, main fonksiyonlarını sınar).
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from datetime import datetime, timedelta, timezone
from io import StringIO
from pathlib import Path
from unittest import mock

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_replay as br  # noqa: E402
import sample_data  # noqa: E402


def make_fake_openf1(past_race_end):
    raw = sample_data.synthetic_session()
    base_dt = datetime(2099, 5, 1, 14, 0, 0, tzinfo=timezone.utc)

    def iso(td_or_sec):
        if isinstance(td_or_sec, (int, float)):
            dt = base_dt + timedelta(seconds=float(td_or_sec))
        else:
            dt = base_dt + pd.to_timedelta(td_or_sec).to_pytimedelta()
        return dt.isoformat().replace("+00:00", "Z")

    def fake_get(endpoint, params=None, retries=4):
        params = params or {}
        if endpoint == "sessions":
            return [
                {
                    "session_key": 9001,
                    "meeting_key": 101,
                    "meeting_name": "Fake Grand Prix",
                    "session_name": "Race",
                    "session_type": "Race",
                    "country_name": "Fakeland",
                    "circuit_short_name": "Fakeville",
                    "date_start": base_dt.isoformat().replace("+00:00", "Z"),
                    "date_end": past_race_end.isoformat().replace("+00:00", "Z"),
                },
                {
                    "session_key": 9002,
                    "meeting_key": 102,
                    "meeting_name": "Future Grand Prix",
                    "session_name": "Race",
                    "session_type": "Race",
                    "country_name": "Futureland",
                    "circuit_short_name": "Futureville",
                    "date_start": (base_dt + timedelta(days=7)).isoformat().replace("+00:00", "Z"),
                    "date_end": None,
                },
            ]
        if endpoint == "drivers":
            return [
                {
                    "driver_number": int(r["number"]),
                    "name_acronym": r["code"],
                    "full_name": r["name"],
                    "team_name": r["team"],
                    "team_colour": r["color"],
                }
                for r in raw.results
            ]
        if endpoint == "session_result":
            return [
                {"driver_number": int(r["number"]), "position": r["position"]}
                for r in raw.results
            ]
        if endpoint == "laps":
            rows = []
            for _, row in raw.laps.iterrows():
                rows.append({
                    "driver_number": int(row["DriverNumber"]),
                    "lap_number": int(row["LapNumber"]),
                    "date_start": iso(row["LapStartTime"]),
                    "lap_duration": pd.to_timedelta(row["LapTime"]).total_seconds(),
                    "is_pit_out_lap": False,
                })
            return rows
        if endpoint == "pit":
            return [
                {
                    "driver_number": 2,
                    "lap_number": 2,
                    "date": iso(138.0),
                    "pit_duration": 5.0,
                }
            ]
        if endpoint == "location":
            num = str(params.get("driver_number"))
            df = raw.pos.get(num)
            if df is None:
                return []
            # Konum verisinin SessionTime değerlerini 0.0 saniyeden başlatıp lapa uyumlu hale getiriyoruz
            loc_rows = []
            for _, r in df.iterrows():
                sec = pd.to_timedelta(r["SessionTime"]).total_seconds()
                loc_rows.append({"date": iso(sec), "x": float(r["X"]), "y": float(r["Y"])})
            return loc_rows
        if endpoint == "car_data":
            num = str(params.get("driver_number"))
            df = raw.car.get(num)
            if df is None:
                return []
            car_rows = []
            for _, r in df.iterrows():
                sec = pd.to_timedelta(r["SessionTime"]).total_seconds()
                car_rows.append({
                    "date": iso(sec),
                    "speed": float(r["Speed"]),
                    "n_gear": int(r["nGear"]),
                    "throttle": float(r["Throttle"]),
                    "brake": 100 if r["Brake"] else 0,
                    "drs": int(r["DRS"]),
                })
            return car_rows
        return []

    return fake_get


class AdapterTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.out = self.tmp.name
        end = datetime.now(timezone.utc) - timedelta(days=2)
        self.fake_get = make_fake_openf1(end)
        patcher = mock.patch.object(br, "_openf1_get", side_effect=self.fake_get)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.addCleanup(self.tmp.cleanup)

    def test_load_raw_maps_openf1_objects(self):
        raw = br.load_raw(2099, 1, "R", cache_dir=str(Path(self.out) / "cache"))
        self.assertEqual((raw.event_name, raw.country, raw.circuit), ("Fake Grand Prix", "Fakeland", "Fakeville"))
        self.assertEqual([r["code"] for r in raw.results], ["AAA", "BBB", "CCC", "DDD"])
        self.assertIsNone(raw.results[3]["position"])
        self.assertIn("LapStartTime", raw.laps.columns)
        self.assertEqual(set(raw.pos), {"1", "2", "3", "4"})
        payload = br.build_payload(raw, hz=2)
        self.assertEqual(payload["event"]["name"], "Fake Grand Prix")
        self.assertEqual(len(payload["pits"]), 1)
        self.assertEqual(payload["pits"][0]["pitLane"], 5.0)

    def test_fetch_schedule_parses_utc_and_missing(self):
        schedule = br.fetch_schedule(2099)
        self.assertEqual(schedule[0]["round"], 1)
        self.assertIsNotNone(schedule[0]["race_end_utc"].tzinfo)
        self.assertIsNone(schedule[1]["race_end_utc"])

    def test_explicit_mode_fails_loudly_on_incomplete_data(self):
        buf = StringIO()
        with redirect_stdout(buf):
            code = br.main(["--year", "2099", "--round", "1", "--out", self.out, "--cache", self.out + "/c"])
        self.assertEqual(code, 1)
        self.assertIn("::error::", buf.getvalue())
        self.assertFalse((Path(self.out) / "index.json").exists())

    def test_latest_mode_warns_but_does_not_fail(self):
        buf = StringIO()
        with redirect_stdout(buf):
            code = br.main(["--latest", "--out", self.out, "--cache", self.out + "/c"])
        self.assertEqual(code, 0)
        self.assertIn("::warning::", buf.getvalue())
        self.assertFalse((Path(self.out) / "index.json").exists())

    def test_latest_mode_writes_session_when_data_is_valid(self):
        with mock.patch.object(br, "validate_payload"):
            with redirect_stdout(StringIO()) as buf:
                code = br.main(["--latest", "--out", self.out, "--cache", self.out + "/c"])
        self.assertEqual(code, 0)
        index = json.loads((Path(self.out) / "index.json").read_text(encoding="utf-8"))
        self.assertEqual(len(index["sessions"]), 1)
        self.assertTrue((Path(self.out) / index["sessions"][0]["file"]).exists())
        self.assertIn("OK", buf.getvalue())
        with redirect_stdout(StringIO()) as again:
            self.assertEqual(br.main(["--latest", "--out", self.out, "--cache", self.out + "/c"]), 0)
        self.assertIn("yeni yaris yok", again.getvalue())

    def test_year_round_required_without_latest(self):
        with self.assertRaises(SystemExit):
            with redirect_stdout(StringIO()):
                br.main(["--out", self.out])


if __name__ == "__main__":
    unittest.main()