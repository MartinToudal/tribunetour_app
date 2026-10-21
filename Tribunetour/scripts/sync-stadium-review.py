#!/usr/bin/env python3
"""Validate and apply approved stadium review rows to the canonical CSV."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[1]
CANONICAL = ROOT / "stadiums.csv"
REVIEW = ROOT / "stadium_review.csv"
LOG = ROOT / "stadium_review_log.json"

REVIEW_FIELDS = [
    "id",
    "team",
    "name",
    "city",
    "country_code",
    "league",
    "season_id",
    "lat",
    "lon",
    "sync_status",
    "source_url",
    "checked_at",
    "reviewer",
    "notes",
]
EDITABLE_FIELDS = [
    "team",
    "name",
    "city",
    "league",
    "season_id",
    "lat",
    "lon",
]
STATUSES = {"pending", "approved", "applied", "rejected"}


def read_csv(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames:
            raise ValueError(f"Mangler header: {path}")
        return list(reader.fieldnames), list(reader)


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def parse_coordinate(value: str, field: str, row_id: str) -> float:
    try:
        number = float(value)
    except ValueError as error:
        raise ValueError(f"{row_id}: {field} skal være et tal") from error
    limit = 90 if field == "lat" else 180
    if not -limit <= number <= limit:
        raise ValueError(f"{row_id}: {field} ligger uden for gyldigt interval")
    return number


def validate_review(canonical: list[dict[str, str]], review: list[dict[str, str]]) -> None:
    canonical_by_id = {row["id"]: row for row in canonical}
    if len(canonical_by_id) != len(canonical):
        raise ValueError("Canonical stadiums.csv indeholder dublerede id'er")

    seen: set[str] = set()
    for row in review:
        row_id = row.get("id", "").strip()
        status = row.get("sync_status", "").strip().lower()
        if not row_id:
            raise ValueError("Alle review-rækker skal have et stabilt id")
        if row_id in seen:
            raise ValueError(f"Review-filen indeholder id flere gange: {row_id}")
        seen.add(row_id)
        if row_id not in canonical_by_id:
            raise ValueError(f"Ukendt id i review-filen: {row_id}")
        if status not in STATUSES:
            raise ValueError(f"{row_id}: sync_status skal være en af {sorted(STATUSES)}")
        parse_coordinate(row.get("lat", ""), "lat", row_id)
        parse_coordinate(row.get("lon", ""), "lon", row_id)
        if status == "approved":
            source_url = row.get("source_url", "").strip()
            parsed = urlparse(source_url)
            if parsed.scheme not in {"http", "https"} or not parsed.netloc:
                raise ValueError(f"{row_id}: approved kræver en gyldig source_url")
            if not row.get("checked_at", "").strip():
                raise ValueError(f"{row_id}: approved kræver checked_at")
            if not row.get("reviewer", "").strip():
                raise ValueError(f"{row_id}: approved kræver reviewer")


def export_review() -> None:
    _, canonical = read_csv(CANONICAL)
    rows = []
    for source in canonical:
        rows.append(
            {
                "id": source["id"],
                "team": source["team"],
                "name": source["name"],
                "city": source["city"],
                "country_code": source["country_code"],
                "league": source["league"],
                "season_id": source["season_id"],
                "lat": source["lat"],
                "lon": source["lon"],
                "sync_status": "pending",
                "source_url": "",
                "checked_at": "",
                "reviewer": "",
                "notes": "",
            }
        )
    write_csv(REVIEW, REVIEW_FIELDS, rows)
    print(f"Eksporterede {len(rows)} stadioner til {REVIEW}")


def apply_approved() -> int:
    canonical_fields, canonical = read_csv(CANONICAL)
    review_fields, review = read_csv(REVIEW)
    missing = set(REVIEW_FIELDS) - set(review_fields)
    if missing:
        raise ValueError(f"Review-filen mangler kolonner: {sorted(missing)}")
    validate_review(canonical, review)
    canonical_by_id = {row["id"]: row for row in canonical}
    now = datetime.now(timezone.utc).isoformat()
    changes = []

    for review_row in review:
        if review_row["sync_status"].strip().lower() != "approved":
            continue
        target = canonical_by_id[review_row["id"]]
        before = {field: target[field] for field in EDITABLE_FIELDS}
        after = {field: review_row[field].strip() for field in EDITABLE_FIELDS}
        if before != after:
            for field, value in after.items():
                target[field] = value
            changes.append(
                {
                    "id": review_row["id"],
                    "team": target["team"],
                    "applied_at": now,
                    "before": before,
                    "after": after,
                    "source_url": review_row["source_url"].strip(),
                    "reviewer": review_row["reviewer"].strip(),
                    "notes": review_row["notes"].strip(),
                }
            )
        review_row["sync_status"] = "applied"
        review_row["notes"] = (review_row["notes"].strip() + " | Applied " + now).strip(" |")

    if changes:
        write_csv(CANONICAL, canonical_fields, canonical)
        write_csv(REVIEW, REVIEW_FIELDS, review)
        previous = []
        if LOG.exists():
            previous = json.loads(LOG.read_text(encoding="utf-8"))
        LOG.write_text(json.dumps(previous + changes, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Anvendte {len(changes)} godkendte stadionændringer")
    return len(changes)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices={"export", "validate", "apply-approved"})
    args = parser.parse_args()
    try:
        if args.action == "export":
            export_review()
        else:
            canonical_fields, canonical = read_csv(CANONICAL)
            review_fields, review = read_csv(REVIEW)
            if set(REVIEW_FIELDS) - set(review_fields):
                raise ValueError("Review-filen har ikke den forventede struktur")
            validate_review(canonical, review)
            if args.action == "apply-approved":
                apply_approved()
            else:
                print(f"Valideret {len(review)} review-rækker")
        return 0
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"FEJL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
