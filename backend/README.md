# Personal data service

This FastAPI service is optional. The Flutter app can be developed and previewed without it.

## Start
```bash
pip install -r requirements.txt
uvicorn app.main:app --reload
```

## Planned adapters
- `jolpica.py`: schedule, race results, driver/team standings.
- `fastf1_importer.py`: post-session laps, stints, telemetry, weather and pit data.
- `rss_importer.py`: feed ingestion with attribution and canonical URLs.

Do not mark a session final until the source has published the required data and the
importer has passed completeness checks.
