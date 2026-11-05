from datetime import datetime, timezone
from fastapi import FastAPI

app = FastAPI(
    title="F1 Tracker Personal Data Service",
    version="0.1.0",
    description="Free-source post-session data service starter.",
)

@app.get("/health")
def health():
    return {
        "status": "ok",
        "service": "f1-tracker",
        "utc_time": datetime.now(timezone.utc).isoformat(),
    }

@app.get("/sync-status")
def sync_status():
    # Replace with persisted sync-job state when the importer is implemented.
    return {
        "state": "not_configured",
        "last_successful_sync": None,
        "message": "No real F1 source has been connected yet.",
    }
