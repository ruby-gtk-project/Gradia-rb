# Component identification

This skill's output for this audit is the inventory already on disk at
`.reports/component-inventory.md`, produced by a prior pass of this same
skill against `origin/main` vs. `lib/`. It was re-read and spot-checked
in this audit, not simply trusted: re-checking it against the current
`ruby` HEAD found one stale row — `lib/quick_color_picker.rb` was ported
in a commit made after the inventory was last written, and the inventory
still said "no" for it. That row is corrected in this pass (see
`.reports/component-inventory.md`'s Totals section). Every other row was
re-derived from scratch and reached the same conclusions the existing
inventory already stated.

Headline counts from that inventory, corrected by this pass:

- **Present**: ~26 of the ~58 upstream units it lists (the graphics/model
  layer, most standalone widgets/selectors/buttons, several dialogs, and
  now the quick color picker).
- **MISSING outright**: the main window (`GradiaMainWindow`), the image
  stack, the image sidebar, the drawing-tools group, the drawing overlay
  that drives pointer input into the drawing-action model, the crop
  overlay, the zoom/pan controller, the preferences window and all five
  of its pages, the OCR backend/dialog/launcher, and the image
  load/export flow (open, paste, save, copy, share).
- Window-level actions and accelerators have **no home**: `ShortcutsDialog`
  exists and documents shortcuts that no `win.*` action in the port
  actually installs, because the window that would install them does not
  exist.

See `.reports/component-inventory.md` for the full per-file table, now
corrected (one row) and re-verified as of `origin/ruby` HEAD
(`f90fb2c`) and `origin/main` HEAD at the time of this audit. The one
correction (quick color picker) does not change the headline finding:
the main window, image stack, sidebar, drawing/crop overlays, zoom
controller, preferences window and all its pages, and the OCR
dialog/launcher are still entirely missing.

## What this audit adds

1. **The gschema file itself is absent from the port's `data/`.** Upstream
   ships `data/be.alexandervanhee.gradia.gschema.xml`; the port's `data/`
   has no schema file at all. `lib/settings.rb` documents this as a
   deliberate substitution (a JSON file under `XDG_CONFIG_HOME` instead of
   `Gio::Settings`, to avoid requiring a schema-install step to run from a
   checkout) and names its reasoning honestly in its header comment — this
   is not a hidden gap, but it does mean the port's settings never talk to
   `dconf`/`gsettings` the way upstream's do, which is a real behavioral
   difference worth a reader's attention.
2. **No `.desktop` file in the port's `data/`.** Upstream ships
   `data/be.alexandervanhee.gradia.desktop.in.in`; nothing in the port
   provides a launcher entry, so there is no desktop-integration component
   to even assess for parity.
3. **No `po/` directory at all.** Covered fully by the translation-parity
   report, but it belongs in the component inventory too: every
   translatable string in every missing window/dialog/page above also has
   no catalogue entry, compounding the component gap with a text gap on
   top of it.
