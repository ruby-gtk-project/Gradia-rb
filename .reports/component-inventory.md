# Gradia-rb component inventory

Survey of upstream `origin/main` (Python/GTK4/libadwaita, `gradia/` + `data/ui/*.blp`)
against the `ruby` branch's `lib/`. Per the `component-identification` skill: the
component is the *set* of upstream files that back one unit (a `.py` class plus its
`.blp` template, where one exists), mapped to the one `lib/<thing>.rb` the house style
puts it in. "Exists" means that unit has a `lib/*.rb` file that implements it — not
merely that some file mentions it in a comment.

Legend for **Kind**: `window` / `dialog` / `page` / `selector` / `widget` /
`overlay` / `backend` / `util` / `data`.

## 1. Application shell

| Upstream file(s) | → lib path | Kind | Exists? |
|---|---|---|---|
| `gradia/main.py` (`GradiaApp`) | `lib/application.rb` | app | Partial — entry point, stylesheet/icon install, window actions for ported widgets only. Actions needing unported loaders/exporters/overlays (`open`, `screenshot`, `open-path`, `load-drop`, `create-source-image`, `preferences`, …) are not registered. |
| `gradia/main.py` (style install) | `lib/style.rb` | util | Yes |
| `gradia/ui/window.py` (`GradiaMainWindow`) + `data/ui/main_window.blp` | — (folded into `lib/application.rb`) | window | **Partial** — split view, sidebar clamp/scroller/header and the welcome-page content area exist; the window's own class (header actions, image/editing mode switch, drag-and-drop target, the toast overlay, save/export entry points) is not a standalone unit yet. |
| `gradia/ui/image_sidebar.py` + `data/ui/image_sidebar.blp` | — | page | **Missing**. Only the background-selector slot of the sidebar (via `Application#background_selector`) is wired; the full `ImageSidebar` (crop/draw/text tool groups, aspect-ratio row wiring together, export controls) has no `lib/*.rb`. |
| `gradia/ui/image_stack.py` + `data/ui/image_stack.blp` | — | widget | **Missing** |
| `gradia/ui/pin_window.py` | — | window | **Missing** (screenshot "pin to screen" window) |
| `gradia/app_constants.py` | `lib/app_constants.rb` | util | Yes |
| `gradia/clipboard.py` | `lib/clipboard.rb` | backend | Yes |

## 2. Dialogs

| Upstream file(s) | → lib path | Kind | Exists? |
|---|---|---|---|
| `gradia/ui/ui_parts.py` (`AboutDialog`) | `lib/about_dialog.rb` | dialog | Yes |
| `gradia/ui/ui_parts.py` (`ShortcutsDialog`) | `lib/shortcuts_dialog.rb` | dialog | Yes |
| `gradia/ui/dialog/confirm_close_dialog.py` + `data/ui/confirm_close_dialog.blp` | `lib/confirm_close_dialog.rb` | dialog | Yes |
| `gradia/ui/dialog/delete_screenshots_dialog.py` | `lib/delete_screenshots_dialog.rb` | dialog | Yes |
| `gradia/ui/dialog/ocr_dialog.py` + `data/ui/ocr_dialog.blp` | — | dialog | **Missing** |
| `gradia/ui/dialog/ocr_launcher.py` | — | backend | **Missing** |
| `gradia/ui/widget/gradient_step_dialog_button.py` + `data/ui/gradient_step_dialog.blp` | `lib/gradient_step_dialog.rb` | dialog | Yes |
| `gradia/ui/image_creation/source_image_generator.py` + `data/ui/image_generator_window.blp` | — | window | **Missing** ("create source image" window) |
| `data/ui/text_entry_popover.blp` + `gradia/overlay/text_entry_popover.py` | — | widget | **Missing** |

## 3. Preferences subsystem (entirely unported)

| Upstream file(s) | → lib path | Kind | Exists? |
|---|---|---|---|
| `gradia/ui/preferences/preferences_window.py` + `data/ui/preferences_window.blp` | — | window | **Missing** |
| `gradia/ui/preferences/ocr_model_page.py` + `data/ui/preferences/ocr_model_page.blp` | — | page | **Missing** |
| `gradia/ui/preferences/provider_selection_window.py` + `data/ui/preferences/provider_list_page.blp`, `provider_detail_page.blp`, `custom_provider_page.blp` | — | window/page | **Missing** |
| `gradia/ui/provider_selection_window.py` | — | window | **Missing** (duplicate/legacy of the above — check both against current upstream before porting either) |
| `data/ui/preferences/screenshot_guide_page.blp` | — | page | **Missing** |
| `gradia/backend/ocr.py` | — | backend | **Missing** |

## 4. Background/color selectors (sidebar)

| Upstream file(s) | → lib path | Kind | Exists? |
|---|---|---|---|
| `gradia/ui/background_selector.py` + `data/ui/background_selector.blp` | `lib/background_selector.rb` | selector | Yes |
| `gradia/graphics/background.py` (`Background` interface) | `lib/background.rb` | backend | Yes |
| `gradia/graphics/gradient.py` | `lib/gradient.rb` | backend | Yes |
| `gradia/graphics/gradient_selector.py` + `data/ui/selectors/gradient_selector.blp` | `lib/gradient_selector.rb` | selector | Yes |
| `gradia/ui/widget/gradient_editor.py` | `lib/gradient_editor.rb` | widget | Yes |
| `gradia/ui/widget/angle_selector.py` | `lib/angle_selector.rb` | widget | Yes |
| `gradia/graphics/solid.py` (`SolidBackground`) | `lib/solid_background.rb` | backend | Yes |
| `gradia/graphics/solid.py` (`SolidSelector`, `ColorPresetButton`, `ColorPickerButton`) + `data/ui/selectors/solid_selector.blp` | `lib/solid_selector.rb`, `lib/preset_button.rb` | selector/widget | Yes |
| `gradia/graphics/image.py` (`ImageBackground`) | `lib/image_background.rb` | backend | Yes |
| `gradia/graphics/image.py` (`ImageSelector`) + `data/ui/selectors/image_selector.blp` | `lib/image_selector.rb` | selector | Yes |
| `gradia/overlay/transparency_overlay.py` | `lib/transparency_background.rb` | widget | Yes |
| `gradia/ui/widget/toggle_group.py` | `lib/toggle_group.rb` | widget | Yes |
| `gradia/ui/widget/background_aspect_ratio_selector.py` | `lib/aspect_ratio_selector.rb` | widget | Yes |
| `gradia/utils/aspect_ratio.py` | `lib/aspect_ratio.rb` | util | Yes |
| `gradia/ui/widget/aspect_ratio_button.py` | `lib/aspect_ratio_button.rb` | widget | Yes |
| `gradia/ui/widget/font_dropdown.py` | — | widget | **Missing** |
| `gradia/ui/widget/quick_color_picker.py` | — | widget | **Missing** |

## 5. Drawing / crop / zoom overlay subsystem (mostly unported)

This is the image-editing canvas — the single largest unported area.

| Upstream file(s) | → lib path | Kind | Exists? |
|---|---|---|---|
| `gradia/overlay/drawing_overlay.py` | — | overlay | **Missing** (the drawing canvas itself) |
| `gradia/overlay/drawing_actions.py` | `lib/drawing_actions.rb` | backend | Yes (the undo/redo action-stack model; the overlay widget that uses it is not ported) |
| `gradia/overlay/crop_overlay.py` | — | overlay | **Missing** |
| `gradia/overlay/zoom_controller.py` | — | overlay/controller | **Missing** |
| `gradia/overlay/drop_overlay.py` + (no dedicated `.blp`) | `lib/drop_overlay.rb` | overlay | Yes |
| `gradia/ui/drawing_tools_group.py` + `data/ui/drawing_tools_group.blp` | — | widget | **Missing** |
| `gradia/ui/widget/drawing_tools_grid.py` | — | widget | **Missing** |
| `gradia/backend/tool_config.py` | `lib/tool_config.rb` | backend | Yes |
| `gradia/utils/colors.py` | `lib/colors.rb` | util | Yes |

## 6. Welcome page / recent files

| Upstream file(s) | → lib path | Kind | Exists? |
|---|---|---|---|
| `gradia/ui/welcome_page.py` + `data/ui/welcome_page.blp` | `lib/welcome_page.rb` | page | Yes |
| `gradia/ui/recent_picker.py` (`RecentPicker`, `RecentFile`, `RecentImageGetter`) + `data/ui/recent_picker.blp` | `lib/recent_picker.rb` | widget | Yes |
| `gradia/ui/recent_picker.py` (`ShadowedImageCard`) | `lib/shadowed_image_card.rb` | widget | Yes |
| App menu (built in `gradia/ui/window.py`, menu model not in this `.blp` set) | `lib/app_menu.rb` | widget | Yes |

## 7. Backend / util (non-widget)

| Upstream file(s) | → lib path | Kind | Exists? |
|---|---|---|---|
| `gradia/backend/logger.py` | `lib/logger.rb` | backend | Yes |
| `gradia/backend/settings.py` | `lib/settings.rb` | backend | Yes (hand-rolled `Gio::Settings`-equivalent load/save; see note below) |
| `gradia/utils/std_image_loader.py` | `lib/std_image_loader.rb` | util | Yes |
| `gradia/utils/timestamp_filename.py` | `lib/timestamp_filename.rb` | util | Yes |
| `gradia/graphics/loaded_image.py` | `lib/loaded_image.rb` | backend | Yes |
| `gradia/graphics/image_processor.py` | — | backend | **Missing** |
| `gradia/ui/image_exporters.py` | — | backend | **Missing** |
| `gradia/ui/image_loaders.py` | — | backend | **Missing** |

## 8. Data / resources (not Ruby components, tracked for parity)

| Upstream file | Kind | Status |
|---|---|---|
| `data/be.alexandervanhee.gradia.gschema.xml` | data | Partially mirrored by hand in `lib/settings.rb` (comment at the top of that file says so); no `Gio::Settings`/schema compiling is used, by design — flag for `component-parity`/`translation-parity` to confirm every key is covered. |
| `data/gradia.gresource.xml.in` | data | N/A for the Ruby port — house style has no `.ui`/GResource bundle; the icons/CSS it lists (`data/style.css`, `data/icons/scalable/actions/*`) should still be checked for 1:1 asset parity (not covered by this survey). |
| `po/*.po`, `po/gradia.pot`, `po/POTFILES.in` | data | **Not ported.** No `gettext`/`GLib.dgettext` call exists anywhere under `lib/` (checked: zero hits). All strings in `lib/*.rb` are hard-coded English with no i18n layer — a gap for `translation-parity` to size. |
| `data/help.txt`, `data/models.json`, `data/screenshot_folder_names.json` | data | Unreferenced by anything in `lib/` yet — these back the OCR/preferences subsystem (section 3), which is unported. |

## Summary

- Upstream `gradia/` Python package: 45 `.py` files (excluding 4 `__init__.py` package markers) plus 22 `data/ui/*.blp` templates.
- `lib/` on `ruby`: 34 files, of which 33 are ported components/support files (`lib/gradia.rb` is the require-all aggregator, `lib/gradia/rb/version.rb` is gem plumbing).
- **Fully unported, upstream-file level:** `gradia/ui/window.py` (as its own unit), `gradia/ui/image_sidebar.py`, `gradia/ui/image_stack.py`, `gradia/ui/pin_window.py`, `gradia/ui/drawing_tools_group.py`, `gradia/ui/widget/drawing_tools_grid.py`, `gradia/ui/widget/font_dropdown.py`, `gradia/ui/widget/quick_color_picker.py`, `gradia/overlay/drawing_overlay.py`, `gradia/overlay/crop_overlay.py`, `gradia/overlay/zoom_controller.py`, `gradia/overlay/text_entry_popover.py`, `gradia/ui/image_creation/source_image_generator.py`, `gradia/ui/image_exporters.py`, `gradia/ui/image_loaders.py`, `gradia/graphics/image_processor.py`, the entire preferences/OCR subsystem (`gradia/ui/preferences/*`, `gradia/ui/provider_selection_window.py`, `gradia/ui/dialog/ocr_dialog.py`, `gradia/ui/dialog/ocr_launcher.py`, `gradia/backend/ocr.py`), and the `po/` translation catalogue (no i18n call sites at all).
- **Ported and matching the house style:** the full background/gradient/solid/image selector stack, the welcome page and recent-picker, the about/shortcuts/confirm-close/delete-screenshots dialogs, the gradient-step dialog, drop overlay, drawing-actions model, and all backend/util singletons (logger, settings, clipboard, tool config, std image loader, timestamp filenames, colors, aspect ratio).
- The biggest remaining area by file count and by user-facing surface is the editing canvas (drawing/crop/zoom overlays + the tool-selection widgets that drive them) and the whole preferences/OCR flow — neither has a single `lib/*.rb` file yet.
