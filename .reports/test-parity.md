# Test parity

## Upstream census

```
git ls-tree -r --name-only origin/main | grep -iE "test|spec"
```

returns nothing that is actually a test file — only incidental path matches
(`aspect_ratio_button.py`, `background_aspect_ratio_selector.py`,
`aspect_ratio.py`, and SVG icon names containing "ratio"). **Upstream Gradia
ships no automated test suite.** There is no pytest directory, no `tests/`,
no CI test job in the upstream repo to census. The formal test-parity
bijection (upstream test N ↔ port test N) is therefore vacuously 0 = 0 — but
that fact must be stated explicitly, not inferred by a reader from silence,
because it changes what the port's own suite is allowed to claim credit for:
none of it can claim to be "ported from upstream tests," since there are none
to port.

## The port's own suite

`spec/` contains exactly two files: `spec/README.md` (documentation for the
`kettle-test` harness) and `spec/spec_helper.rb`. **There are zero
`*_spec.rb` files anywhere in the repository.** Running the suite the way
the dev shell's own banner says to:

```
nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'
```

produces:

```
NOTE: kettle-test isn't installed; running with plain RSpec.
No examples found.
0 examples, 0 failures
```

A full RSpec + `kettle-test` harness was scaffolded (`.rspec`,
`.rspec_status`, `spec/spec_helper.rb`, `spec/README.md`, gemfiles) and never
used. This is scaffolding, not coverage. "0 examples, 0 failures" is a green
exit code; it is not a passing test suite, and treating it as one is exactly
the false-green pattern the accountability-ensurance pass must catch (see
that report).

## What actually runs: `test/drive_app.rb`

`test/drive_app.rb` is an 853-line manual smoke-test script (not RSpec, no
`describe`/`it`) that drives the live app under `xvfb-run` and asserts 193
`d.check(...)` conditions, grouped into 85 numbered steps. Run directly:

```
nix develop --command xvfb-run -a ruby test/drive_app.rb
```

returns `193 of 193 checks passed` / `DRIVE OK` — this is the "193 checks
passed, 0 failed, covering 40 components" the task's runtime gate cites.

Three things a reader must not infer from that number:

1. **It is not a port of any upstream test**, because upstream has none to
   port from. It is original test-writing by the porting agent, which is
   legitimate work, but it is not "test parity" in the sense this skill
   measures — there is no upstream census it maps onto.
2. **It only exercises components that exist.** Its own header comment
   says so outright: it drives "the overlay split view, the welcome page
   ..., and every widget those are built from," plus six widgets (FontDropdown,
   TextEntryPopover, DrawingToolsGrid, PinWindow, QuickColorPicker,
   SimpleColorPicker) "ported but not yet wired into any parent widget by
   the app itself," in a
   scratch window built solely for the test. It does not and cannot
   exercise the main window, image stack, sidebar, OCR flow, preferences,
   crop, zoom, or image load/export, because none of those exist (see
   component-identification / component-parity reports). A check suite
   that cannot reach code that doesn't exist has not verified that code is
   fine; it has simply never looked.
3. **At least one check's "pass" encodes an absence, not a capability.**
   Step 2 includes: `d.check('the loaders are not ported, so win.open is
   absent') { app.window.lookup_action('open').nil? }`. This is written
   honestly — the check's own name says what's missing — but it means the
   193/193 total is partly built from assertions that a missing feature is
   still missing, not from assertions that a feature works. Rolling that
   into a single "193 passed" headline number flattens "verified working"
   and "verified absent" into the same green tally.

## Verdict

**Test parity: not established, and the suite that exists cannot establish
it.** There is no upstream suite to count against (state this plainly rather
than silently reporting 0/0 as success). The port's chosen test framework
(RSpec via `kettle-test`) has zero specs and has therefore never been
exercised at all for this app. The only suite that has actually run and
passed is a hand-written smoke test that: (a) is not a parity artifact
against anything upstream, (b) by its own documentation only reaches the
~40% of the app that exists, and (c) counts "feature confirmed absent" checks
toward the same total as "feature confirmed working" checks. Citing
"193/193, DRIVE OK" as evidence the port is tested is a narrower claim than
it's usually read as — the next report (accountability-ensurance) treats
over-reading that number as a false-green risk in its own right.
