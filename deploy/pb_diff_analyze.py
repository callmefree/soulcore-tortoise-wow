# -*- coding: utf-8 -*-
import difflib, re, os

ours = r'C:\Users\ADMINI~1\AppData\Local\Temp\pb_ours'
new  = r'C:\Users\ADMINI~1\AppData\Local\Temp\pb_new'

inc_add = inc_del = real_add = real_del = 0
for dp, _, fns in os.walk(ours):
    for f in fns:
        if not f.endswith(('.cpp', '.h')):
            continue
        full = os.path.join(dp, f)
        rel = os.path.relpath(full, ours).replace(os.sep, '/')
        npath = os.path.join(new, rel)
        if not os.path.exists(npath):
            continue
        a = open(full, encoding='utf-8', errors='replace').read().splitlines()
        b = open(npath, encoding='utf-8', errors='replace').read().splitlines()
        for l in difflib.unified_diff(a, b, lineterm=''):
            if l.startswith('+') and not l.startswith('+++'):
                body = l[1:].strip()
                if body.startswith('#include'):
                    inc_add += 1
                elif body:
                    real_add += 1
            elif l.startswith('-') and not l.startswith('---'):
                body = l[1:].strip()
                if body.startswith('#include'):
                    inc_del += 1
                elif body:
                    real_del += 1

tot = inc_add + inc_del + real_add + real_del
print('include changes: +%d/-%d' % (inc_add, inc_del))
print('real code changes: +%d/-%d' % (real_add, real_del))
print('include ratio: %.0f%%' % ((inc_add + inc_del) / tot * 100))

# conf new keys
a = open(os.path.join(ours, 'aiplayerbot.conf.dist.in'), encoding='utf-8', errors='replace').read().splitlines()
b = open(os.path.join(new, 'aiplayerbot.conf.dist.in'), encoding='utf-8', errors='replace').read().splitlines()

def keys(lines):
    s = set()
    for l in lines:
        m = re.match(r'^\s*#?\s*AiPlayerbot\.(\w+)', l)
        if m:
            s.add(m.group(1))
    return s

print()
print('=== NEW config keys in official ===')
for k in sorted(keys(b) - keys(a)):
    print(' +AiPlayerbot.' + k)
print()
print('=== config keys only in ours ===')
for k in sorted(keys(a) - keys(b)):
    print(' -AiPlayerbot.' + k)
