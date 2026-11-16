"""FastF1'e dokunan kodun (load_raw, fetch_schedule, main) SAHTE bir fastf1 modülüyle testi.

Gerçek FastF1 API'sini doğrulamaz; yalnızca bizim kodumuzun beklediğimiz alan adlarıyla doğru
çalıştığını ve hata yollarının beklendiği gibi davrandığını sınar.
"""
import json
import sys
import tempfile
import types
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


def make_fake_fastf1(past_race_end):
    raw = sample_data.synthetic_session()

    class FakeSession:
        def __init__(self, year, rnd, code):
            self.event = pd.Series({"EventName": "Fake Grand Prix", "Country": "Fakeland", "Location": "Fakeville"})
            self.results = pd.DataFrame([
                {"DriverNumber": r["number"], "Abbreviation": r["code"], "FullName": r["name"],
                 "TeamName": r["team"], "TeamColor": r["color"], "Position": float(r["position"]) if r["position"] else float("nan")}
                for r in raw.results
            ])
            self.laps = raw.laps.assign(Driver="X", Stint=1.0)   # fazladan kolonlar yok sayılmalı
            self.car_data = raw.car
            self.pos_data = raw.pos
            self.loaded = None

        def load(self, **kwargs):
            self.loaded = kwargs

    module = types.ModuleType("fastf1")
    module.Cache = types.SimpleNamespace(enable_cache=lambda path: None)
    module.get_session = lambda year, rnd, code: FakeSession(year, rnd, code)
    module.get_event_schedule = lambda year, include_testing=False: pd.DataFrame([
        {"RoundNumber": 1, "Session5DateUtc": pd.Timestamp(past_race_end.replace(tzinfo=None))},
        {"RoundNumber": 2, "Session5DateUtc": pd.NaT},
    ])
    return module


class AdapterTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.out = self.tmp.name
        end = datetime.now(timezone.utc) - timedelta(days=2)
        self.fake = make_fake_fastf1(end)
        patcher = mock.patch.dict(sys.modules, {"fastf1": self.fake})
        patcher.start()
        self.addCleanup(patcher.stop)
        self.addCleanup(self.tmp.cleanup)

    def test_load_raw_maps_fastf1_objects(self):
        raw = br.load_raw(2099, 1, "R", cache_dir=str(Path(self.out) / "cache"))
        self.assertEqual((raw.event_name, raw.country, raw.circuit), ("Fake Grand Prix", "Fakeland", "Fakeville"))
        self.assertEqual([r["code"] for r in raw.results], ["AAA", "BBB", "CCC", "DDD"])
        self.assertEqual(raw.results[3]["position"], None)           # NaN -> None
        self.assertIn("LapStartTime", raw.laps.columns)
        self.assertNotIn("Stint", raw.laps.columns)
        self.assertEqual(set(raw.pos), {"1", "2", "3", "4"})
        payload = br.build_payload(raw, hz=2)
        self.assertEqual(payload["event"]["name"], "Fake Grand Prix")

    def test_fetch_schedule_parses_utc_and_missing(self):
        schedule = br.fetch_schedule(2099)
        self.assertEqual(schedule[0]["round"], 1)
        self.assertIsNotNone(schedule[0]["race_end_utc"].tzinfo)
        self.assertIsNone(schedule[1]["race_end_utc"])

    def test_explicit_mode_fails_loudly_on_incomplete_data(self):
        # 4 pilotlu sentetik seans varsayılan bütünlük eşiklerini (>=10 pilot) geçemez.
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
        # İkinci çalışma: zaten işlendi, yeni iş yok.
        with redirect_stdout(StringIO()) as again:
            self.assertEqual(br.main(["--latest", "--out", self.out, "--cache", self.out + "/c"]), 0)
        self.assertIn("yeni yarış yok", again.getvalue())

    def test_year_round_required_without_latest(self):
        with self.assertRaises(SystemExit):
            with redirect_stdout(StringIO()):
                br.main(["--out", self.out])


if __name__ == "__main__":
    unittest.main()
