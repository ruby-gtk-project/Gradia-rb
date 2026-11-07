# Accountability ensurance

## Grep for excusing language

```
grep -rniE "TODO|FIXME|not implemented|for now|in a future" lib exe
```
→ no matches.

```
grep -rniE "TODO|FIXME|not implemented|for now|in a future|never (run|executed)|not .* run|has not been" .reports
```
→ one match, in the pre-existing `.reports/component-inventory.md`:
"...not re-verified key-by-key in this pass... Not re-verified... has not
been checked, not that it's fine." That sentence is the opposite of the
failure this skill hunts: it states a gap plainly and explicitly refuses to
claim it's fine. It is not load-bearing excuse language; it is the correct
shape of honesty this skill wants to see more of.

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

The task's runtime gate is **drive_ok=true, 171 checks passed, 0 failed,
covering 34 components.** Read in isolation, that is a green gate. Read
against what this audit found in the other four reports, it is a **false
or at minimum badly overclaimed green**, for three compounding reasons,
each independently confirmed in this audit:

1. **"34 components" is being measured against a port that is missing its
   main window, image stack, sidebar, drawing overlay, crop, zoom, OCR
   (entire feature), preferences (entire window), and image load/export.**
   Per `.reports/component-inventory.md`, that's roughly half the upstream
   component inventory. A gate that reports "34 components, 0 failed" next
   to a component inventory that independently lists this many MISSING
   rows is not a contradiction only because the 34 checked components were
   never claimed to be all of them — but presenting "171 passed, 0 failed"
   as *the* runtime gate for the whole port, without the component count
   it was taken from sitting next to the inventory's missing-list, is
   exactly the setup for a reader to over-credit it. This report is
   flagging that risk explicitly so the number is never read alone again.
2. **At least one of those 171 "passed" checks asserts a feature's
   absence as success**, by its own name: `d.check('the loaders are not
   ported, so win.open is absent') { app.window.lookup_action('open').nil? }`
   (`test/drive_app.rb`, step 2). This is written honestly in the moment —
   the check's label says exactly what it's really testing — but it means
   the single headline number "171 of 171 checks passed" is not 171
   confirmations that functionality works. It is some unknown mix of
   "works as designed" and "confirmed still missing," collapsed into one
   green tally. Nothing downstream of that number (including the task
   prompt that cites it as this round's gate) can currently tell those
   two kinds of check apart without reading all 751 lines of the script.
   That is the false-green risk this skill exists to name: a true,
   accurately-labeled check whose result is nonetheless reported upward
   in a way that reads as more reassuring than it is.
3. **The port's actual chosen test framework has never been run with a
   single spec in it.** `spec/` holds zero `*_spec.rb` files;
   `RSpec::Core::Runner` reports `0 examples, 0 failures`. That is a
   passing exit code and zero verification. If anyone cites "the test
   suite passes" without qualifying which suite, that sentence is false
   for the RSpec suite and true-but-narrow for `drive_app.rb`. No document
   in this repository currently makes that distinction before this audit.

## Verdict

**No deliberate excuse-writing was found in `lib/`, `exe/`, or any
pre-existing report — that specific failure mode is absent.** But the
runtime gate this round is being asked to trust (171/171, DRIVE OK, 34
components) is not the clean signal it looks like: it is a narrow,
honestly-labeled smoke test over the roughly-half of the app that exists,
mixed with absence-confirming checks, standing in for a formally-configured
RSpec suite that has executed zero examples. Call this what it is — **a
green gate measuring a fraction of the app, with no document in the repo
saying so until this one** — rather than letting "171 passed, 0 failed"
be read as "the port works."
