#!/usr/bin/env bash
# Build the public copy of this repo: the committed tree, redacted. Run from
# your laptop, inside this repo.
#
#   ./scripts/export-public.sh <dest-dir>
#
# This repo stays private and is the only one edited; the public repo is
# generated from it. The export takes HEAD, so uncommitted changes are left
# out. It applies scripts/export-public/redactions.tsv, blanks MAC addresses,
# and refuses the result if a mapped value, a MAC, or a public IP or domain
# missing from allowlist.txt is left, or if gitleaks finds anything.
# redactions.tsv holds the real values, so it is never exported.
#
# <dest-dir> is normally a clone of the public repo: everything but its .git is
# replaced. Nothing is committed or pushed; review `git diff` there first.
set -euo pipefail

dest=${1:?usage: export-public.sh <dest-dir>}
here=$(cd "$(dirname "$0")" && pwd)
repo=$(git rev-parse --show-toplevel)
cfg=$here/export-public

say() { printf '\033[31mexport-public: %s\033[0m\n' "$1" >&2; }

# Guard the wipe below: dest must be empty, or a clone of some other repo.
mkdir -p "$dest"
dest=$(cd "$dest" && pwd)
case "$dest/" in
  "$repo"/*) say "refusing: $dest is inside this repo"; exit 1 ;;
esac
if [ -n "$(ls -A "$dest")" ] && [ ! -d "$dest/.git" ]; then
  say "refusing: $dest is not empty and not a git clone"; exit 1
fi

find "$dest" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
git -C "$repo" archive HEAD -- . ':(exclude)scripts/export-public/redactions.tsv' | tar -x -C "$dest"

python3 -I "$cfg/redact.py" "$dest" "$cfg/redactions.tsv" "$cfg/allowlist.txt" \
  || { say "export blocked: fix the redaction map or the allow-list, then rerun"; exit 1; }
gitleaks dir --no-banner --redact "$dest" \
  || { say "export blocked: gitleaks found something"; exit 1; }

echo "Exported $(git -C "$repo" rev-parse --short HEAD) to $dest. Review it, then commit and push from there."
