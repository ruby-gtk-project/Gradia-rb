# Accountability ensurance

## Grep for excusing language

```
grep -rniE "TODO|FIXME|not implemented|for now|in a future" lib exe
```
→ re-run against `lib/` and `exe/` at the current `ruby` HEAD (`59f3f19`,
including the new `lib/ocr_dialog.rb`): no matches.

```
grep -rniE "TODO|FIXME|not implemented|for now|in a future|never (run|executed)|not .* run|has not been" .reports
```
→ re-run against the current `.reports/` (after this pass's corrections to
`component-inventory.md`, `component-identification.md`,
`component-parity.md` and `test-parity.md` for the OCR dialog landing and
the drive script growing from 193/40 to 200/48 checks/components): no
matches outside this file's own and `test-parity.md`'s quoted grep
commands and the deliberate "never been exercised"/"not re-verified"
sentences those two reports use to state a gap plainly. That is the
correct use of that language, not an instance of the failure mode: a
sentence admitting a gap was not checked, in a report whose job is to say
so, is the opposite of excuse-writing. No instance of `lib/` or `exe/`
code writing itself permission to skip something was found in either
pass.

There is no `PORTING.md` or `FINDINGS.md` in this repository to grep.
`lib/settings.rb`'s header explaining why it swaps `Gio::Settings` for a
JSON file is a documented engineering tradeoff with its reasoning shown,
not a note excusing an unbuilt feature — it's naming a decision it did
make, not a decision to skip something. That one is fine as written.

**So: no instance of a port writing itself a permission slip.** The
specific failure mode this skill was created to catch (console-rb's
"Dropped deliberately" section) does not appear in Gradia-rb's own
documents. That is the good news, and it is the only good news in this
audit.

## The real accountability problem here is not a sentence — it's a number

The task's runtime gate this round is **drive_ok=true, 200 checks passed,
0 failed, covering 48 components** (re-run live for this audit: confirmed
`200 of 200 checks passed` / `DRIVE OK`, up from 193/40 in the prior
round's gate, because of the OCR dialog's addition in `59f3f19`). Read in
isolation, that is a green gate. Read against what this audit found in
the other four reports, it is a **false or at minimum badly overclaimed
green**, for four compounding reasons, three carried over unchanged from
the prior pass and one new in this run:

1. **"48 components" is being measured against a port that is still
   missing its main window, image stack, sidebar, drawing overlay, crop,
   zoom, the OCR launcher, preferences (entire window), and image
   load/export.** Per `.reports/component-inventory.md`, that's still
   roughly half the upstream component inventory — the OCR *dialog*
   landed this round, but the OCR *feature* (reachable from a real
   window) did not. A gate that reports "48 components, 0 failed" next to
   a component inventory that independently lists this many MISSING rows
   is not a contradiction only because the 48 checked components were
   never claimed to be all of them — but presenting "200 passed, 0
   failed" as *the* runtime gate for the whole port, without the
   component count it was taken from sitting next to the inventory's
   missing-list, is exactly the setup for a reader to over-credit it.
2. **At least one of those 200 "passed" checks asserts a feature's
   absence as success**, by its own name: `d.check('the loaders are not
   ported, so win.open is absent') { app.window.lookup_action('open').nil? }`
   (`test/drive_app.rb`, step 2, unchanged this round). This is written
   honestly in the moment — the check's label says exactly what it's
   really testing — but it means the single headline number "200 of 200
   checks passed" is not 200 confirmations that functionality works. It
   is some unknown mix of "works as designed" and "confirmed still
   missing," collapsed into one green tally.
3. **The port's actual chosen test framework has never been run with a
   single spec in it**, re-confirmed this pass: `spec/` still holds zero
   `*_spec.rb` files; `RSpec::Core::Runner` still reports `0 examples, 0
   failures`. That is a passing exit code and zero verification.
4. **New this round: the drive script's own final screenshot step
   silently failed to render**, and that failure sits inside the "200
   passed" run, not counted against it. Re-running `test/drive_app.rb`
   live for this audit produced `shot 16-window-final failed:
   RuntimeError: widget produced no render node (not realised yet?)`
   immediately before the "200 of 200 checks passed / DRIVE OK" lines,
   alongside several `Gtk-WARNING: Finalizing Gtk{Button,Image,Window},
   but it still has children left: GtkPopover` messages from the OCR
   dialog's teardown. Because screenshot capture is not wired into
   `d.check(...)`, a screenshot that never actually renders still prints
   "DRIVE OK" — this is exactly the "a check that doesn't fire is not the
   same as a check that passes" shape this skill exists to catch, just on
   the artifact side of the harness rather than the assertion side.

## Verdict

**No deliberate excuse-writing was found in `lib/`, `exe/`, or any
pre-existing report — that specific failure mode is absent, confirmed
again this round.** But the runtime gate this round is being asked to
trust (200/200, DRIVE OK, 48 components) is not the clean signal it looks
like: it is a narrow, honestly-labeled smoke test over roughly half the
upstream component surface, mixed with absence-confirming checks and at
least one silently-failed screenshot capture, standing in for a
formally-configured RSpec suite that has executed zero examples. Call
this what it is — **a green gate measuring a fraction of the app, with a
render failure inside the very run that produced the green number** —
rather than letting "200 passed, 0 failed" be read as "the port works."
