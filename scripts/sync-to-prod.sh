#!/usr/bin/env bash
#
# Dev-to-Prod sync: rsync this project to a remote host over SSH.
# Copies only changed files. Use --dry-run first to preview.
#
# Usage:
#   ./sync-to-prod.sh [user@]host [remote-path] [--dry-run]
#
# Default remote-path: Bars (relative to remote home or absolute).
# Optional: set DRY_RUN=1 or pass --dry-run as third argument to preview only.
#
# Default excluded paths (not copied):
#   - backend DB: backend/pentest_toolbox.db, backend/*.db
#   - backend/storage/, backend/reports/, reports/, storage/, host_agent/venv/
#   - __pycache__/, *.pyc, node_modules/, .git/, .env, *.log
#
# WARNING: --delete is used: files on remote that no longer exist locally
# will be removed. Run with --dry-run first to verify.
#
# Requires: rsync (and openssh-client) on this host; rsync on the remote host.
# On the remote, install with: apt install rsync  (or  yum install rsync)
#
set -eu

REMOTE="${1:?Usage: $0 [user@]host [remote-path] [--dry-run]}"
REMOTE_PATH="${2:-Bars}"
DRY_RUN="${DRY_RUN:-0}"
if [[ "${3:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Ensure rsync is available on the remote (rsync over SSH runs rsync on both sides)
if ! ssh "$REMOTE" "command -v rsync" &>/dev/null; then
  echo "Error: rsync is not installed on the remote host ($REMOTE)." >&2
  echo "Install it there, e.g.: ssh $REMOTE 'sudo apt install -y rsync'" >&2
  exit 1
fi

RSYNC_OPTS=(-avz --delete)
if [[ "$DRY_RUN" == "1" ]]; then
  RSYNC_OPTS+=(-n)
  echo "Dry run (no changes will be made)."
fi

# Default excludes: DB, storage, reports, host_agent/venv, caches, node_modules, .git, .env, logs
RSYNC_OPTS+=(
  --exclude='backend/pentest_toolbox.db'
  --exclude='backend/*.db'
  --exclude='backend/storage/'
  --exclude='backend/reports/'
  --exclude='reports/'
  --exclude='storage/'
  --exclude='host_agent/venv/'
  --exclude='__pycache__/'
  --exclude='*.pyc'
  --exclude='node_modules/'
  --exclude='.git/'
  --exclude='.env'
  --exclude='*.log'
)

exec rsync "${RSYNC_OPTS[@]}" ./ "$REMOTE:$REMOTE_PATH/"
