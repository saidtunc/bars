#!/usr/bin/env bash
#
# Sync Bars code to another machine (e.g. second VM for collaborative work).
# Excludes: .env, all *.db files, and optional dev artifacts (node_modules, venv, etc.).
#
# Usage:
#   ./sync-to-remote.sh [user@host] [remote_path]
#   Or set REMOTE_TARGET and optionally REMOTE_PATH in the script or env.
#
# Examples:
#   ./sync-to-remote.sh kali@192.168.1.102
#   ./sync-to-remote.sh kali@192.168.1.102 /home/kali/Bars
#   REMOTE_TARGET=kali@vm2 ./sync-to-remote.sh
#

set -euo pipefail

# --- Configuration (override with env or pass as arguments) ---
REMOTE_TARGET="${REMOTE_TARGET:-}"
REMOTE_PATH="${REMOTE_PATH:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Use -rltvp (no -o/-g) so remote never tries chown/chgrp — avoids "Operation not permitted" when remote user can't set group
# Omitting --delete so files created only on the remote are not removed when you push from local
RSYNC_OPTS=(-rltvp)

# Optional: set to "1" to also exclude storage/ and reports/ on remote (keeps only code)
SYNC_EXCLUDE_STORAGE_AND_REPORTS="${SYNC_EXCLUDE_STORAGE_AND_REPORTS:-0}"

if [[ $# -ge 1 ]]; then
  REMOTE_TARGET="$1"
fi
if [[ $# -ge 2 ]]; then
  REMOTE_PATH="$2"
fi

if [[ -z "$REMOTE_TARGET" ]]; then
  echo "Usage: $0 <user@host> [remote_path]"
  echo "   Or: REMOTE_TARGET=user@host [REMOTE_PATH=/path] $0"
  echo ""
  echo "Examples:"
  echo "  $0 kali@192.168.1.102"
  echo "  $0 kali@192.168.1.102 /home/kali/Bars"
  exit 1
fi

# Default remote path: same as local dir name on remote home
if [[ -z "$REMOTE_PATH" ]]; then
  REMOTE_PATH="~/$(basename "$SCRIPT_DIR")"
fi

# Build exclude list: never sync .env or DB files
EXCLUDES=(
  --exclude='.env'
  --exclude='.env.*'
  --exclude='*.db'
  --exclude='*.db-journal'
  --exclude='*.db-wal'
  --exclude='*.db-shm'
  --exclude='__pycache__'
  --exclude='.git'
  --exclude='node_modules'
  --exclude='.cursor'
  --exclude='*.pyc'
  --exclude='.pytest_cache'
  --exclude='.mypy_cache'
  --exclude='.ruff_cache'
)
# Optional: exclude storage and reports so only code is synced
if [[ "$SYNC_EXCLUDE_STORAGE_AND_REPORTS" == "1" ]]; then
  EXCLUDES+=(--exclude='storage/' --exclude='reports/')
fi
# Exclude venvs so the other machine uses its own
EXCLUDES+=(--exclude='venv/' --exclude='backend/venv/' --exclude='host_agent/venv/')

echo "Syncing: $SCRIPT_DIR -> $REMOTE_TARGET:$REMOTE_PATH"
echo "Excluded: .env, .env.*, *.db, __pycache__, .git, node_modules, venv, .cursor"
if [[ "$SYNC_EXCLUDE_STORAGE_AND_REPORTS" == "1" ]]; then
  echo "Also excluded: storage/, reports/"
fi
echo ""

rsync "${RSYNC_OPTS[@]}" "${EXCLUDES[@]}" \
  "$SCRIPT_DIR/" "$REMOTE_TARGET:$REMOTE_PATH/"

echo "Done. Restart app on the remote machine if it is running."
