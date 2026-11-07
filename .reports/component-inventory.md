# Gradia component inventory

Surveyed upstream `origin/main` (Python/GTK4/Libadwaita, app id
`be.alexandervanhee.gradia`) against the `ruby` branch's `lib/`. No app code
was written in this step.

Legend: **present** = a `lib/*.rb` file already ports the upstream file/class.
**MISSING** = no corresponding `lib/*.rb` file exists at all.

## Windows

| Upstream file | Class | lib/*.rb target | Kind | Present? |
|---|---|---|---|---|
| `gradia/ui/window.py` + `data/ui/main_window.blp` | `GradiaMainWindow` | `lib/main_window.rb` | window | **MISSING** — the app's actual main window (image stack, sidebar, header bar, view-switching) has no port. `lib/application.rb` only ports `gradia/main.py` (the `Adw.Application` subclass), not the window it opens. |
| `gradia/ui/image_creation/source_image_generator.py` + `data/ui/image_generator_window.blp` (`SourceviewtestWindow`) | source/code-snippet generator window | `lib/source_image_generator.rb` | window | **MISSING** |
| `gradia/ui/preferences/preferences_window.py` + `data/ui/preferences_window.blp` | `PreferencesWindow` (`GradiaPreferencesWindow`) | `lib/preferences_window.rb` | preferences dialog (Adw.PreferencesDialog) | **MISSING** |

## Dialogs

| Upstream file | Class | lib/*.rb target | Kind | Present? |
|---|---|---|---|---|
| `gradia/ui/ui_parts.py` (`AboutDialog`) | `AboutDialog` | `lib/about_dialog.rb` | dialog | present |
| `gradia/ui/ui_parts.py` (`ShortcutsDialog`) | `ShortcutsDialog` | `lib/shortcuts_dialog.rb` | dialog | present |
| `gradia/ui/dialog/confirm_close_dialog.py` + `data/ui/confirm_close_dialog.blp` | `ConfirmCloseDialog` | `lib/confirm_close_dialog.rb` | dialog | present |
| `gradia/ui/dialog/delete_screenshots_dialog.py` | `DeleteScreenshotsDialog` | `lib/delete_screenshots_dialog.rb` | dialog | present |
| `gradia/ui/widget/gradient_step_dialog_button.py` + `data/ui/gradient_step_dialog.blp` (`CssGradientDialog`, `GradientStepRow`, `GradientStepDialogButton`) | 3 classes | `lib/gradient_step_dialog.rb` | dialog + row + button | present |
| `gradia/ui/dialog/ocr_dialog.py` + `data/ui/ocr_dialog.blp` (`OCRDialog`) | `OCRDialog` | `lib/ocr_dialog.rb` | dialog | **MISSING** |
| `gradia/ui/dialog/ocr_launcher.py` | OCR capture/launch flow (no class — module-level helper) | `lib/ocr_launcher.rb` | action/flow helper | **MISSING** |

## Preferences pages

| Upstream file | Class | lib/*.rb target | Kind | Present? |
|---|---|---|---|---|
| `gradia/ui/preferences/ocr_model_page.py` + `data/ui/preferences/ocr_model_page.blp` | `OCRModelPage` | `lib/ocr_model_page.rb` | Adw.NavigationPage | **MISSING** |
| `gradia/ui/preferences/preferences_window.py` (`ScreenshotGuidePage`) + `data/ui/preferences/screenshot_guide_page.blp` (`GradiaScreenshotGuidePage`) | `ScreenshotGuidePage` | `lib/screenshot_guide_page.rb` | Adw.NavigationPage | **MISSING** |
| `gradia/ui/preferences/provider_selection_window.py` (also duplicated verbatim at `gradia/ui/provider_selection_window.py` — upstream dead-code duplication, flag but don't resolve it here) (`ProviderListPage`) + `data/ui/preferences/provider_list_page.blp` | `ProviderListPage` | `lib/provider_list_page.rb` | Adw.NavigationPage | **MISSING** |
| same file (`CustomProviderPage`) + `data/ui/preferences/custom_provider_page.blp` | `CustomProviderPage` | `lib/custom_provider_page.rb` | Adw.NavigationPage | **MISSING** |
| same file (`ProviderDetailPage`) + `data/ui/preferences/provider_detail_page.blp` | `ProviderDetailPage` | `lib/provider_detail_page.rb` | Adw.NavigationPage | **MISSING** |

## Pages / stacks / sidebars

| Upstream file | Class | lib/*.rb target | Kind | Present? |
|---|---|---|---|---|
| `gradia/ui/welcome_page.py` + `data/ui/welcome_page.blp` | welcome/empty-state page | `lib/welcome_page.rb` | page (empty state) | present |
| `gradia/ui/image_stack.py` + `data/ui/image_stack.blp` (`GradiaImageStack`) | main image/annotation canvas stack | `lib/image_stack.rb` | Adw.Bin / stack | **MISSING** |
| `gradia/ui/image_sidebar.py` + `data/ui/image_sidebar.blp` (`GradiaImageSidebar`) | tool/background/export sidebar | `lib/image_sidebar.rb` | Adw.Bin | **MISSING** |
| `gradia/ui/drawing_tools_group.py` + `data/ui/drawing_tools_group.blp` (`GradiaDrawingToolsGroup`) | annotation tool palette | `lib/drawing_tools_group.rb` | Box/toolbar group | **MISSING** |
| `gradia/ui/widget/drawing_tools_grid.py` | tool grid widget feeding the group above | `lib/drawing_tools_grid.rb` | widget | **MISSING** |
| `gradia/ui/pin_window.py` | "pin to screen" floating window | `lib/pin_window.rb` | window | **MISSING** |

## Selectors / widgets (background & color)

| Upstream file | Class | lib/*.rb target | Kind | Present? |
|---|---|---|---|---|
| `gradia/ui/background_selector.py` + `data/ui/background_selector.blp` | `BackgroundSelector` | `lib/background_selector.rb` | Adw.PreferencesGroup / selector | present |
| `gradia/graphics/gradient_selector.py` + `data/ui/selectors/gradient_selector.blp` | `GradientSelector` | `lib/gradient_selector.rb` | selector | present |
| `gradia/graphics/image.py` (`ImageSelector`) + `data/ui/selectors/image_selector.blp` | `ImageSelector` | `lib/image_selector.rb` | selector | present |
| `gradia/graphics/solid.py` (`SolidSelector`) + `data/ui/selectors/solid_selector.blp` | `SolidSelector` | `lib/solid_selector.rb` | selector | present |
| `gradia/graphics/solid.py` (`ColorPresetButton`, `ColorPickerButton`) | 2 button classes | `lib/solid_selector.rb` | button | present |
| `gradia/ui/widget/preset_button.py` (`BasePresetButton`, `GradientPresetButton`, `ImagePresetButton`) | 3 button classes | `lib/preset_button.rb` | button | present |
| `gradia/ui/widget/gradient_editor.py` (`GradientColorButton`, `GradientEditor`) | 2 classes | `lib/gradient_editor.rb` | widget | present |
| `gradia/ui/widget/angle_selector.py` | `AngleSelector` | `lib/angle_selector.rb` | widget | present |
| `gradia/ui/widget/aspect_ratio_button.py` | `AspectRatioButton` | `lib/aspect_ratio_button.rb` | button | present |
| `gradia/ui/widget/background_aspect_ratio_selector.py` | `AspectRatioSelector` | `lib/aspect_ratio_selector.rb` | Adw.ActionRow | present |
| `gradia/ui/widget/toggle_group.py` | `ToggleGroup` | `lib/toggle_group.rb` | Box | present |
| `gradia/ui/widget/font_dropdown.py` | `FontDropdown` | `lib/font_dropdown.rb` | DropDown | present |
| `gradia/ui/widget/quick_color_picker.py` | quick color picker popover/button used by the drawing toolbar | `lib/quick_color_picker.rb` | widget | **MISSING** |
| `gradia/ui/recent_picker.py` + `data/ui/recent_picker.blp` (`RecentFile`, `RecentImageGetter`, main widget; `ShadowedImageCard`) | 4 units | `lib/recent_picker.rb`, `lib/shadowed_image_card.rb` | selector/card | present |
| `gradia/overlay/text_entry_popover.py` + `data/ui/text_entry_popover.blp` | `TextEntryPopover` | `lib/text_entry_popover.rb` | popover | present |

## Overlays / canvas behavior

| Upstream file | Class | lib/*.rb target | Kind | Present? |
|---|---|---|---|---|
| `gradia/overlay/drop_overlay.py` | `DropOverlay` | `lib/drop_overlay.rb` | Adw.Bin | present |
| `gradia/overlay/transparency_overlay.py` | `TransparencyBackground` | `lib/transparency_background.rb` | Gtk.Widget | present |
| `gradia/overlay/drawing_actions.py` (`DrawingMode`, `QuadBounds`, `DrawingAction` + 9 concrete actions) | 11 units | `lib/drawing_actions.rb` | action/model | present |
| `gradia/overlay/drawing_overlay.py` | the overlay widget that actually hosts/dispatches `drawing_actions.py`'s actions on the canvas (pointer/gesture handling, redraw, selection) | `lib/drawing_overlay.rb` | Gtk.Widget overlay | **MISSING** — the actions exist in the port but nothing drives them from pointer input |
| `gradia/overlay/crop_overlay.py` | `CropOverlay` | `lib/crop_overlay.rb` | Gtk.Widget overlay | **MISSING** |
| `gradia/overlay/zoom_controller.py` | zoom/pan gesture controller for the canvas | `lib/zoom_controller.rb` | Gtk.EventController | **MISSING** |

## Backend / non-widget logic

| Upstream file | lib/*.rb target | Kind | Present? |
|---|---|---|---|
| `gradia/main.py` | `lib/application.rb` | Adw.Application | present |
| `gradia/app_constants.py` + `gradia/constants.in` | `lib/app_constants.rb` | constants | present |
| `gradia/clipboard.py` | `lib/clipboard.rb` | helper | present |
| `gradia/backend/logger.py` | `lib/logger.rb` | logging | present |
| `gradia/backend/settings.py` | `lib/settings.rb` | GSettings wrapper | present (see note below) |
| `gradia/backend/tool_config.py` | `lib/tool_config.rb` | model | present |
| `gradia/backend/ocr.py` | `lib/ocr.rb` | OCR backend (model download, inference, provider calls) | **MISSING** — nothing in `lib/` performs OCR; `OCRDialog`, `OCRModelPage`, `ocr_launcher.py` and the whole preferences provider-selection flow all depend on this and are also missing |
| `gradia/graphics/background.py` (`Background` ABC) | `lib/background.rb` | abstract model | present |
| `gradia/graphics/gradient.py` | `lib/gradient.rb` | model | present |
| `gradia/graphics/image.py` (`ImageBackground`) | `lib/image_background.rb` | model | present |
| `gradia/graphics/image_processor.py` | `lib/image_processor.rb` | model | present |
| `gradia/graphics/loaded_image.py` | `lib/loaded_image.rb` | model | present |
| `gradia/graphics/solid.py` (`SolidBackground`) | `lib/solid_background.rb` | model | present |
| `gradia/graphics/gradient_gen.c` | (native gradient renderer upstream's `gradient.py`/`gradient_selector.py` link against) | — | present — `lib/gradient.rb`'s header notes upstream's C renderer is replaced by Cairo; confirm that comment holds given the `ruby-gtk` skill's own caution about rolling bespoke code where a gem/binding exists |
| `gradia/utils/aspect_ratio.py` | `lib/aspect_ratio.rb` | model | present |
| `gradia/utils/colors.py` | `lib/color_conversions.rb` | helper | present |
| `gradia/utils/std_image_loader.py` | `lib/std_image_loader.rb` | helper | present |
| `gradia/utils/timestamp_filename.py` | `lib/timestamp_filename.rb` | helper | present |
| `gradia/ui/image_exporters.py` | `lib/image_exporters.rb` | export (save/copy/share flow) | **MISSING** |
| `gradia/ui/image_loaders.py` | `lib/image_loaders.rb` | load flow (open/paste/CLI-arg image loading into the stack) | **MISSING** |

## Menus, actions, shortcuts, style

| Upstream source | lib/*.rb target | Kind | Present? |
|---|---|---|---|
| `menu app_menu` block in `data/ui/welcome_page.blp` / `main_window.blp` | `lib/app_menu.rb` | Gio.Menu | present |
| `data/style.css` | `lib/style.rb` | CSS provider | present |
| Keyboard shortcuts (declared in `gradia/ui/window.py`'s action/accel setup, surfaced via `ShortcutsDialog` in `ui_parts.py`) | `lib/shortcuts_dialog.rb` only shows the dialog; the window's own `win.*` actions and accelerators have no home since `lib/main_window.rb` doesn't exist | actions/accels | **MISSING** (dialog text exists, the actions it documents don't) |

## GSettings schema

`data/be.alexandervanhee.gradia.gschema.xml` declares 28 keys. `lib/settings.rb`
wraps `gradia/backend/settings.py`, but with no `lib/main_window.rb`,
`lib/preferences_window.rb`, `lib/ocr_model_page.rb` or provider pages, most of
those keys (window size/state, OCR provider/model choice, screenshot-folder
list, etc.) have no Ruby code that reads or writes them yet. Not re-verified
key-by-key in this pass — flagging it as a follow-up for whoever picks up the
missing pages above, since the gap is in the pages, not the schema file.

## GResource manifest

`data/gradia.gresource.xml.in` bundles `data/style.css` (ported, `lib/style.rb`),
the symbolic action icons under `data/icons/scalable/actions/` (consumed by
the widgets above, not a separate component), the bundled font
(`data/fonts/Caveat-VariableFont_wght.ttf`) and the `data/source-styles/*.xml`
GtkSourceView theme files. The font and source-style resources back
`source_image_generator.py` (the code/source-snippet window) and have no Ruby
counterpart since that window is missing (see Windows table above).

## po/ catalogue

`po/LINGUAS` lists 20 translated languages plus `po/gradia.pot`. Full
msgid-by-msgid translation parity was not run in this pass (that is the
`translation-parity` skill's job, separate from this component survey) — noting
only that it has not been checked, not that it's fine.

## Summary

- `lib/` currently has 40 files and already ports the full graphics/model
  layer (`background.py`, `gradient.py`, `image.py`, `solid.py`,
  `image_processor.py`, `loaded_image.py`), the drawing-action model, most
  standalone widgets/selectors/buttons, and several dialogs.
- The entire windowing layer is missing: no `GradiaMainWindow`, no
  `GradiaImageStack`, no `GradiaImageSidebar`, no `GradiaDrawingToolsGroup` —
  i.e. nothing currently assembles the ported widgets into the app's actual
  window. `lib/application.rb` opens no window today.
- The whole OCR feature (backend, dialog, model-selection page, provider
  selection/custom-provider/provider-detail pages, launcher) is missing.
- The crop, zoom/pan, and live drawing-overlay controllers that drive the
  already-ported `drawing_actions.rb` model from actual pointer input are
  missing, so that model currently has nothing to call it.
- Image load/export flows (open, paste, save, copy, share) are missing.
- Preferences (the window itself, plus every page in it) is entirely missing.
- `gradia/ui/provider_selection_window.py` duplicates
  `gradia/ui/preferences/provider_selection_window.py` byte-for-byte upstream;
  flagged here, not resolved — whoever ports it should pick one upstream
  source and say so, not silently merge them without a note.
