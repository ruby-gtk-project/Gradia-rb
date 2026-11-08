# Component parity

Component parity requires, per component, that count, style, behaviour and
text all match upstream. This audit cannot certify any of the four axes for
most of the app, because most of the app's components do not exist in the
port at all — there is nothing to compare axes against.

## Components that cannot be assessed because they are missing

Every row marked **MISSING** in `.reports/component-inventory.md` is a
component-parity failure by definition, not an open question:

- `GradiaMainWindow` (the actual main window — image stack, sidebar, header
  bar, view switching)
- `GradiaImageStack`, `GradiaImageSidebar`, `GradiaDrawingToolsGroup`
- the drawing overlay, crop overlay, zoom/pan controller
- the preferences window and all five of its pages (OCR model page,
  screenshot-guide page, provider-list/custom-provider/provider-detail
  pages)
- `ocr_launcher` (the backend's `OCRDialog` *presentation* is now ported —
  see the spot-check below — but the launcher that upstream uses to open
  it from the real window is not, because the window isn't)
- `source_image_generator` window
- image load/export flows (open, paste, save, copy, share)
- the window's own `win.*` actions and accelerators (the `ShortcutsDialog`
  text describes shortcuts that bind to nothing, because the window that
  would own those actions doesn't exist)

A port with no main window has no app-level component graph to join to
upstream's. Calling any of the above "partial" would overstate it: zero
lines of the owning class exist, so count/style/behaviour/text are all
simultaneously unmet by construction.

## Components that exist and were spot-checked

For the roughly half of the inventory marked present, this audit spot-checked
a handful rather than exhaustively walking all four axes on all ~26 files
(that would be its own multi-day pass). Spot checks:

- `lib/confirm_close_dialog.rb`, `lib/delete_screenshots_dialog.rb`,
  `lib/gradient_step_dialog.rb` — present, built with the house
  memoized/`.tap` style, and read as faithful to their upstream
  counterparts' widget trees on inspection.
- `lib/quick_color_picker.rb` (ported since the prior pass of this report)
  — count and behaviour read as faithful: same 6 base swatches plus a
  "more colours" button in `QuickColorPicker`, same 6 swatches plus
  Transparent plus "more colours" in `SimpleColorPicker`'s popover,
  wired to the same system colour dialog. **Text axis fails**: upstream
  marks every one of 'Red', 'Green', 'Blue', 'Yellow', 'Black', 'White',
  'Transparent', 'More Colors' and 'Choose Color' with `_()`
  (`gradia/ui/widget/quick_color_picker.py:24-108`); the port's version
  has every one of those same nine strings as a bare literal with no
  translation marker — one more component-level instance of the gap the
  translation-parity report states at the catalogue level.
- `lib/ocr_dialog.rb` (ported since the prior pass of this report, commit
  `59f3f19`) — count and behaviour read as faithful on the axes the drive
  script exercises: language dropdown starting on the stored model,
  loading → text / no-text stack pages, copy-to-clipboard with a toast.
  **Text axis fails here too**: the dialog's page titles and the copy
  button/toast strings are bare Ruby literals; upstream's
  `gradia/ui/dialog/ocr_dialog.py` wraps its equivalents in `_()`. It is
  also only reachable from `test/drive_app.rb`'s scratch window — there is
  no `ocr_launcher` wiring it to a real action, so it cannot be opened
  from the app as the app does not yet have an app to open it from.
- `lib/drawing_actions.rb` ports the 9 concrete `DrawingAction` subclasses
  and `DrawingMode`/`QuadBounds` as a model, but — per the inventory — has
  no `drawing_overlay.rb` to ever invoke it from pointer input. A model
  with no caller is not a parity pass; it's unreachable code that happens
  to be correctly shaped.
- `lib/settings.rb` keeps upstream's key names/defaults/signatures but
  swaps `Gio::Settings` + the compiled gschema for a hand-rolled JSON
  store (documented, not hidden — see component-identification report).
  This is a behavioral deviation on every setting the UI pages would read,
  though none of those pages exist yet to exercise it.

**This audit does not certify full four-axis parity on any single
component**, including the ones that exist, because doing so for ~26 files
against their upstream Python/Blueprint sources is outside what this pass
completed. Treat the "present" column in the component inventory as "a file
exists and was not read line-by-line against upstream in this pass" rather
than as "parity proven."

## Verdict

**Component parity: failing, and failing on the majority of the app's
surface area**, not on edge cases. The parts that make Gradia usable as an
app — opening a window, loading a screenshot, drawing on it, exporting it,
running OCR, changing preferences — are the parts missing. The parts present
are almost entirely the supporting model/widget layer those missing parts
would assemble.
