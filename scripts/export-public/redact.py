#!/usr/bin/env python3
"""Redact an exported tree in place, then refuse it if anything sensitive is left.

  redact.py <tree> <redactions.tsv> <allowlist.txt>

redactions.tsv: one `from<TAB>to` per line, literal and case-sensitive, applied
in file order, so longer strings go first. `\\n` in either column is a newline,
so an entry can remove whole lines (an empty `to` deletes). A `to` of `!BLOCK`
replaces nothing: the export is refused while that value is present, for things
that must be dropped by hand rather than anonymised. MAC addresses are blanked
without being listed. allowlist.txt: the public IPs and domains that may appear;
a domain also allows its subdomains. Lines starting with # are comments.

A passage between a line that is only a `private` HTML comment and a line that
is only a `/private` one is removed before anything else; scripts/README.md
shows the two lines. A marker left over, such as an unclosed one, is a problem.

Exits 1 with every leftover as `file:line: what`. A mapped value is matched
case-insensitively, so `SECRET` is caught even though only `secret` is mapped.
"""
import ipaddress
import pathlib
import re
import sys

MAC = re.compile(r'\b(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}\b')
IPV4 = re.compile(r'\b(?:\d{1,3}\.){3}\d{1,3}\b')
# Lowercase hostnames under the TLDs this repo can plausibly mention. .lan and
# .example are not in the list, so LAN names and placeholders pass. File
# extensions that are also TLDs (.sh, .md, .py, .run) are left out on purpose.
DOMAIN = re.compile(
    r'\b(?:[a-z0-9-]+\.)+(?:se|com|net|org|io|dev|nu|eu|app|cloud|me|xyz|info|biz|co|uk|de|fi|no|dk|tv|ai'
    r'|to|ly|gg|link|site|online|tech|page|us|ca|fr|nl|ch|at|pl|jp|au|be|es|cc|pro|top|club|space'
    r'|host|zone|email|blog|live|store|shop|ws|cz|ee|lt|lv|ie|nz)'
    # Not when the name goes on, as `.site` does in `app.site-b.example`.
    r'(?![-\w]|\.[a-z0-9])')
# Built from parts so this file holds no marker line of its own.
MARKER = r'[ \t]*<!-- /?private -->[ \t]*$'
PRIVATE = re.compile(r'^[ \t]*<!-- ' + r'private -->[ \t]*\n.*?^[ \t]*<!-- ' + r'/private -->[ \t]*\n',
                     re.S | re.M)


def entries(path):
    with open(path, encoding='utf-8') as f:
        return [l.rstrip('\n') for l in f if l.strip() and not l.startswith('#')]


def leftovers(rel, text, pairs, blocked, allow):
    for n, line in enumerate(text.splitlines(), 1):
        low = line.lower()
        if re.fullmatch(MARKER, line):
            yield f'{rel}:{n}: private marker left over (unclosed?)'
        for old, new in pairs:
            # A multi-line entry is checked by its lines, so a partial match is
            # caught, except the lines its replacement keeps on purpose.
            for part in filter(None, old.lower().split('\n')):
                if part in new.lower():
                    continue
                if part in low:
                    yield f'{rel}:{n}: mapped value left: {part}'
        for word in blocked:
            if word.lower() in low:
                yield f'{rel}:{n}: blocked value present, drop it in redactions.tsv: {word}'
        if MAC.search(line):
            yield f'{rel}:{n}: MAC address'
        for ip in IPV4.findall(line):
            try:
                public = ipaddress.ip_address(ip).is_global
            except ValueError:
                continue
            if public and ip not in allow:
                yield f'{rel}:{n}: public IP not allowed: {ip}'
        for d in DOMAIN.findall(line):
            if not any(d == a or d.endswith('.' + a) for a in allow):
                yield f'{rel}:{n}: domain not allowed: {d}'


def main(tree, map_path, allow_path):
    rows = [[c.replace('\\n', '\n') for c in l.split('\t')] for l in entries(map_path)]
    pairs = [(old, new) for old, new in rows if new != '!BLOCK']
    blocked = [old for old, new in rows if new == '!BLOCK']
    allow = set(entries(allow_path))
    tree = pathlib.Path(tree)
    problems = []
    files = [p for p in tree.rglob('*') if p.is_file() and '.git' not in p.relative_to(tree).parts]
    for f in sorted(files):
        rel = f.relative_to(tree)
        for old in [o for o, _ in pairs if '\n' not in o] + blocked:
            if old.lower() in str(rel).lower():
                problems.append(f'{rel}: mapped value in file name: {old}')
        try:
            text = f.read_text(encoding='utf-8')
        except UnicodeDecodeError:
            problems.append(f'{rel}: binary file, cannot be checked')
            continue
        text = PRIVATE.sub('', text)
        for old, new in pairs:
            text = text.replace(old, new)
        text = MAC.sub('xx:xx:xx:xx:xx:xx', text)
        f.write_text(text, encoding='utf-8')
        problems.extend(leftovers(rel, text, pairs, blocked, allow))
    for p in problems:
        print(p)
    print(f'redact: {len(files)} files, {len(pairs)} mappings, {len(blocked)} blocked, '
          f'{len(problems)} problems', file=sys.stderr)
    return 1 if problems else 0


if __name__ == '__main__':
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    sys.exit(main(*sys.argv[1:]))
