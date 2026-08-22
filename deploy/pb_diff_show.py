# -*- coding: utf-8 -*-
import difflib, os, sys

ours = r'C:\Users\ADMINI~1\AppData\Local\Temp\pb_ours'
new  = r'C:\Users\ADMINI~1\AppData\Local\Temp\pb_new'

def show(rel, maxlines=50):
    a = open(os.path.join(ours, rel), encoding='utf-8', errors='replace').read().splitlines()
    b = open(os.path.join(new, rel), encoding='utf-8', errors='replace').read().splitlines()
    d = list(difflib.unified_diff(a, b, fromfile='ours', tofile='new', lineterm=''))
    print('=' * 70)
    print('FILE: %s  (diff %d lines)' % (rel, len(d)))
    print('=' * 70)
    out = []
    for l in d:
        if l.startswith('+++') or l.startswith('---'):
            continue
        if l.startswith('+') or l.startswith('-'):
            body = l[1:].strip()
            if body.startswith('#include'):
                continue
            out.append(l)
    for l in out[:maxlines]:
        print(l)
    if len(out) > maxlines:
        print('... (%d more)' % (len(out) - maxlines))
    print()

for rel in sys.argv[1:]:
    show(rel)
