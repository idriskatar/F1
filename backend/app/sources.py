"""
Free-source integration boundaries.

Implementation notes:
- Jolpica: fetch calendar, standings and classifications from its documented API.
- FastF1: load historical session data after the session has completed and upstream
  timing data has been published. Cache FastF1 results locally; do not fetch per app view.
- RSS: ingest headline, summary (if permitted), publication timestamp, publisher and
  canonical article URL. Do not republish full copyrighted articles.
- Validate session identity and data completeness before marking a session final.
"""

from dataclasses import dataclass
from typing import Optional

@dataclass
class SyncResult:
    source: str
    success: bool
    records_written: int = 0
    message: Optional[str] = None

# Source adapters will be implemented in the next milestone.
