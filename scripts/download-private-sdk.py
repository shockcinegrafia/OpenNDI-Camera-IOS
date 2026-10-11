#!/usr/bin/env python3
"""Download a private iPhoneOS SDK ZIP from Drive using a short-lived Google token."""
import hashlib
import os
import pathlib
import sys
import urllib.request

file_id = os.environ.get("SDK_GDRIVE_FILE_ID", "").strip()
expected = os.environ.get("SDK_SHA256", "").strip().lower()
destination = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "sdk-private.zip")
if not file_id or not expected or len(expected) != 64:
    sys.exit("Missing SDK_GDRIVE_FILE_ID or valid SDK_SHA256")
try:
    import google.auth
    from google.auth.transport.requests import Request
except ImportError:
    sys.exit("Install google-auth and requests")
credentials, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/drive.readonly"])
credentials.refresh(Request())
url = "https://www.googleapis.com/drive/v3/files/" + file_id + "?alt=media"
req = urllib.request.Request(url, headers={"Authorization": "Bearer " + credentials.token})
digest = hashlib.sha256()
destination.parent.mkdir(parents=True, exist_ok=True)
with urllib.request.urlopen(req, timeout=90) as response, destination.open("wb") as out:
    while True:
        chunk = response.read(1024 * 1024)
        if not chunk:
            break
        digest.update(chunk)
        out.write(chunk)
if digest.hexdigest() != expected:
    destination.unlink(missing_ok=True)
    sys.exit("SDK SHA-256 mismatch: aborting")
print("Private SDK downloaded and SHA-256 verified")
