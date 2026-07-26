#!/usr/bin/env python3
"""Upload AAB to Google Play internal testing track and optionally complete release."""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

SCOPE = ["https://www.googleapis.com/auth/androidpublisher"]
PACKAGE = "com.theNext.personal_cognitive"
# Play API: internal testing track id is "internal" (legacy docs) or "qa" (newer).
TRACK_CANDIDATES = ("internal", "qa")
ROOT = Path(__file__).resolve().parents[1]


def release_name_from_pubspec(version_code: int | None = None) -> str:
    """Build Play release name like '1.0.12 (16)' from pubspec.yaml."""
    text = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
    match = re.search(r"^version:\s*([0-9]+(?:\.[0-9]+)*)\+(\d+)\s*$", text, re.M)
    if not match:
        return str(version_code) if version_code is not None else "release"
    name, code = match.group(1), int(match.group(2))
    if version_code is not None and version_code != code:
        # Prefer the uploaded bundle code if pubspec drifted.
        return f"{name} ({version_code})"
    return f"{name} ({code})"


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--sa", required=True, help="Service account JSON path")
    p.add_argument("--aab", required=True, help="Path to .aab")
    p.add_argument(
        "--name",
        default=None,
        help="Release name shown in Play Console (default: from pubspec.yaml)",
    )
    p.add_argument(
        "--status",
        default="completed",
        choices=("completed", "draft"),
        help="completed = roll out to testers; draft = upload only",
    )
    args = p.parse_args()

    aab = Path(args.aab)
    if not aab.is_file():
        print(f"AAB not found: {aab}", file=sys.stderr)
        return 1

    creds = service_account.Credentials.from_service_account_file(
        args.sa, scopes=SCOPE
    )
    service = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)

    edit = (
        service.edits()
        .insert(body={}, packageName=PACKAGE)
        .execute()
    )
    edit_id = edit["id"]
    print(f"edit={edit_id}")

    media = MediaFileUpload(str(aab), mimetype="application/octet-stream", resumable=True)
    bundle = (
        service.edits()
        .bundles()
        .upload(packageName=PACKAGE, editId=edit_id, media_body=media)
        .execute()
    )
    version_code = bundle["versionCode"]
    release_name = args.name or release_name_from_pubspec(version_code)
    print(f"uploaded versionCode={version_code} name={release_name}")

    track_body = {
        "track": "internal",
        "releases": [
            {
                "name": release_name,
                "versionCodes": [str(version_code)],
                "status": args.status,
            }
        ],
    }

    last_err = None
    used_track = None
    for track in TRACK_CANDIDATES:
        track_body["track"] = track
        try:
            service.edits().tracks().update(
                packageName=PACKAGE,
                editId=edit_id,
                track=track,
                body=track_body,
            ).execute()
            used_track = track
            print(f"track={track} status={args.status}")
            break
        except Exception as e:  # noqa: BLE001
            last_err = e
            print(f"track {track} failed: {e}")

    if used_track is None:
        print(f"Could not assign track: {last_err}", file=sys.stderr)
        try:
            service.edits().delete(packageName=PACKAGE, editId=edit_id).execute()
        except Exception:
            pass
        return 2

    # Prefer normal commit; some apps reject changesNotSentForReview.
    try:
        commit = (
            service.edits()
            .commit(packageName=PACKAGE, editId=edit_id)
            .execute()
        )
    except Exception as e:
        print(f"commit failed: {e}", file=sys.stderr)
        print(
            "Play Console에서 서비스 계정에 '테스트 트랙으로 앱 출시' 권한을 주거나, "
            "AAB를 콘솔에서 수동 업로드하세요.",
            file=sys.stderr,
        )
        return 3
    print(
        f"committed id={commit.get('id')} track={used_track} "
        f"versionCode={version_code} name={release_name}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
