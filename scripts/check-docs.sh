#!/usr/bin/env bash
# Consistency check for the repo's own documentation. Run it after editing the
# backlog, or let the pre-commit hook run it for you.
#
# Catches the five ways this repo has actually drifted:
#   1. a backlog id that is both open and done
#   2. a markdown link pointing at a file that no longer exists
#   3. a backlog id missing from the sequence
#   4. a backlog id referenced somewhere but never defined
#   5. a link to a #heading that does not exist in the target file
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
# Findings go to a temp file, not a variable: several checks below run inside
# pipelines, and a variable set in a subshell does not survive back to here.
found=$(mktemp)
trap 'rm -f "$found"' EXIT
say() { printf '\033[31m  %s\033[0m\n' "$1"; echo x >> "$found"; }

echo "Checking docs/backlog.md..."

# 1. ids that are both open and done
dupes=$(awk '/^## Done/{d=1} /^- \[/{ if(match($0,/HL-[0-9]+/)) print (d?"done":"open"), substr($0,RSTART,RLENGTH) }' \
        docs/backlog.md | sort -u \
        | awk '{c[$2]=c[$2]" "$1} END{for(i in c) if(c[i]~/open/&&c[i]~/done/) print i}')
[ -n "$dupes" ] && for d in $dupes; do say "$d is listed as both open and done"; done

# 2. broken relative links across all tracked markdown
while IFS= read -r f; do
  d=$(dirname "$f")
  grep -oE '\]\([^)#]+\.(md|sh|yml|ps1)[^)]*\)' "$f" 2>/dev/null \
    | sed -E 's/^\]\(//; s/\)$//; s/#.*$//' \
    | while IFS= read -r link; do
        case "$link" in http*|"") continue ;; esac
        [ -e "$d/$link" ] || say "$f -> missing $link"
      done
done < <(git ls-files '*.md')

# 3. ids missing from the sequence — an item deleted by a bad edit leaves a gap.
#    Deliberate retirements are declared in an HTML comment in the backlog.
retired=$(grep -oE '<!-- retired:[^>]*-->' docs/backlog.md | grep -oE 'HL-[0-9]+' | tr '\n' ' ')
present=$(grep -oE '^- \[[ x~-]\] \*\*HL-[0-9]+' docs/backlog.md | grep -oE '[0-9]+$' | sort -n)
if [ -n "$present" ]; then
  lo=$(echo "$present" | head -1); hi=$(echo "$present" | tail -1)
  i=$lo
  while [ "$i" -le "$hi" ]; do
    padded=$(printf 'HL-%02d' "$i")
    if ! echo "$present" | grep -qx "$(printf '%d' "$i")" && ! echo "$present" | grep -qx "$(printf '%02d' "$i")"; then
      case " $retired " in
        *" $padded "*) ;;
        *) say "$padded is missing from the sequence — deleted by mistake, or add it to the retired list" ;;
      esac
    fi
    i=$((i + 1))
  done
fi

# 4. ids referenced but never defined with a checkbox
defined=$(grep -oE '^- \[[ x~-]\] \*\*HL-[0-9]+' docs/backlog.md | grep -oE 'HL-[0-9]+' | sort -u)
referenced=$(grep -rhoE 'HL-[0-9]+' --include='*.md' --include='*.sh' . 2>/dev/null \
             | grep -v '^\./\.git' | sort -u)
for r in $referenced; do
  echo "$defined" | grep -qx "$r" && continue
  # a retired id may still be named in the retirement note and in history
  case " $retired " in *" $r "*) continue ;; esac
  say "$r is referenced but has no backlog entry"
done

# 5. links to a #heading that does not exist. Anchors are GitHub's: the heading
#    lowercased, punctuation dropped, spaces to hyphens, -1/-2 for repeats.
python3 - <<'PY' | while IFS= read -r msg; do say "$msg"; done
import os, re, subprocess
def slugs(path):
    out, seen, fence = set(), {}, False
    for line in open(path, encoding="utf-8"):
        if line.startswith("```"): fence = not fence
        if fence: continue
        m = re.match(r"#{1,6}\s+(.*?)\s*#*\s*$", line)
        if not m: continue
        s = re.sub(r"[^\w\- ]", "", m.group(1).strip().lower()).replace(" ", "-")
        n = seen.get(s, 0); seen[s] = n + 1
        out.add(s if n == 0 else f"{s}-{n}")
    return out
cache = {}
files = subprocess.run(["git", "ls-files", "*.md"], capture_output=True, text=True).stdout.split()
for f in files:
    text = open(f, encoding="utf-8").read()
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    for link in re.findall(r"\]\(([^)\s]*#[^)\s]+)\)", text):
        if link.startswith("http"): continue
        target, frag = link.split("#", 1)
        path = os.path.normpath(os.path.join(os.path.dirname(f), target)) if target else f
        if not path.endswith(".md") or not os.path.exists(path): continue
        if path not in cache: cache[path] = slugs(path)
        if frag not in cache[path]:
            print(f"{f} -> no heading #{frag} in {path}")
PY

if [ -s "$found" ]; then
  echo "  $(wc -l < "$found" | tr -d ' ') problem(s) found"
  exit 1
fi
echo "  all good"
exit 0
