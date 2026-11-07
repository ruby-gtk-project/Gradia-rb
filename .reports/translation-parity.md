# Translation parity

## Upstream census

```
git ls-tree -r --name-only origin/main | grep -i '^po/'
```

Upstream `po/` has 20 language `.po` files (`ar de es fr hr hu it kk nl oc
pl pt_BR ru sv te tr uk vi zh_CN`), plus `LINGUAS`, `POTFILES.in`,
`meson.build`, and `gradia.pot`. The pot file carries:

```
grep -c '^msgid "' po/gradia.pot   # (read from origin/main)
277
```

277 extracted msgids (counting the empty header entry as one grep hit;
close enough for a count the next pass should re-derive if it matters to
the gram).

## Port state

```
find po -maxdepth 1 -type f    # from the ruby branch checkout
```

returns nothing — **there is no `po/` directory anywhere in the port.** No
`LINGUAS`, no `.pot`, no single `.po` file, for any of the 20 languages.

```
grep -rl "gettext\|FastGettext\|_(" lib exe
```

also returns nothing — **no string anywhere in `lib/` or `exe/` is marked
for translation at all.** Every user-visible string the port does have
(dialog titles, button labels, menu entries, the welcome page, the shortcuts
dialog) is a bare Ruby string literal with no translation marker and no
corresponding msgid.

## What this means against the skill's three claims

1. **Key sets equal?** No. Upstream: 277 keys. Port: 0 keys. Not "0 minus
   the ones in unported files" — literally zero infrastructure exists to
   extract a key in the first place, from any file, ported or not.
2. **Each key byte-identical?** Vacuously inapplicable — there are no port
   keys to compare.
3. **Languages ship?** No. 0 of upstream's 20 `.po` files were copied over,
   and no `.mo` build step exists to produce one even if they were.

## Verdict

**Translation parity: 0%, complete absence, not a partial gap.** This is
the single most unambiguous finding in this audit: it requires no judgment
call about whether a widget "counts" as present, no comparison of CSS
classes — the directory that would hold the evidence does not exist. Every
one of the 20 languages upstream already ships working translations for
goes dark the moment a user runs the port in anything but English, and
every string a future contributor adds has nowhere to register a msgid even
if they wanted to. This is not noted anywhere in `.reports/` prior to this
audit as a settled decision — the existing `component-inventory.md` flags it
once, accurately, as "not re-verified... not that it's fine" — so there is
no accountability violation specific to translation parity being excused in
writing. The violation is simply that the work was never done.
