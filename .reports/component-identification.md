# Component identification

This skill's output for this audit is the inventory already on disk at
`.reports/component-inventory.md`, produced by a prior pass of this same
skill against `origin/main` vs. `lib/`. It was re-read and spot-checked
in this audit, not rewritten, because re-deriving it from scratch reached
the same conclusions.

Headline counts from that inventory, unchanged by this pass:

- **Present**: ~25 of the ~58 upstream units it lists (the graphics/model
  layer, most standalone widgets/selectors/buttons, several dialogs).
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

See `.reports/component-inventory.md` for the full per-file table this
audit confirms is still accurate as of `origin/ruby` HEAD and
`origin/main` HEAD at the time of this audit.

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
