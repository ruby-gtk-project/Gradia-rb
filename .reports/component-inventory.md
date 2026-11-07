# Gradia component inventory — upstream `origin/main` vs. `ruby`

Survey only; no app code was written for this pass. Upstream read via
`git show origin/main:<path>` / `git archive origin/main`, never checked out.

`lib/` on `ruby` as of `7d9ecbb` has 41 component/support files (plus
`lib/gradia.rb`, `lib/gradia/rb/version.rb`, `lib/app_constants.rb`). Upstream
`gradia/` has 44 Python files; `data/ui/` has 24 `.blp` files backing the
GResource bundle in `data/gradia.gresource.xml.in`.

Legend: **kind** — `window`, `dialog`, `page`, `row`/`widget`, `overlay`,
`menu`, `backend` (non-widget support class ported 1:1 the same way),
`shortcuts`, `settings`. **exists** — yes / partial / no.

## Application shell

| Upstream file | → `lib/*.rb` | Kind | Exists |
|---|---|---|---|
| `gradia/main.py` | `lib/application.rb` | application/window-shell | partial — installs style+icons, opens window, registers 6 of upstream's actions (`shortcuts`, `about`, `donate`, `quit`, `toggle-sidebar`, `screenshot`); `open`, `open-path`, `load-drop`, `create-source-image`, `preferences` not registered |
| `gradia/ui/window.py` (`GradiaMainWindow`) | — (folded into `lib/application.rb`) | window | **no** — not its own file; only the split view / sidebar / header bar shell that `application.rb`'s comment admits it borrowed is present. No `ImageStack` content area, no header-bar action buttons, no drag/drop target, no "unsaved changes" close guard |
| `data/ui/main_window.blp` | — | window (blueprint) | **no** |
| `gradia/ui/ui_parts.py` (`AboutDialog`) | `lib/about_dialog.rb` | dialog | yes |
| `gradia/ui/ui_parts.py` (`ShortcutsDialog`) | `lib/shortcuts_dialog.rb` | shortcuts | yes |
| `menu app_menu` in `data/ui/welcome_page.blp` / `main_window.blp` | `lib/app_menu.rb` | menu | yes |
| `data/be.alexandervanhee.gradia.gschema.xml` | `lib/settings.rb` | settings | yes — all ~27 keys read in `lib/settings.rb` match the schema; re-verify when a feature using `source-snippet-*` or `trained-data` lands |
| `data/gradia.gresource.xml.in` | `lib/app_constants.rb` / `lib/style.rb` | resource manifest | partial — icons dir + `style.css` wired (`lib/style.rb`, `lib/app_constants.rb`); `help.txt`, `models.json`, `source-styles/*.xml` not yet consumed by anything in `lib/` |
| `po/*.po`, `po/gradia.pot`, `po/POTFILES.in` | — | translation catalogue | **no** — no `gettext`/`FastGettext` wiring found under `lib/`; out of scope for `translation-parity` pass, flagged here per instructions |

## Welcome / entry

| Upstream file | → `lib/*.rb` | Kind | Exists |
|---|---|---|---|
| `gradia/ui/welcome_page.py` + `data/ui/welcome_page.blp` | `lib/welcome_page.rb` | page | yes |
| `gradia/ui/background_selector.py` + `data/ui/background_selector.blp` | `lib/background_selector.rb` | widget (sidebar) | yes |
| `gradia/ui/image_sidebar.py` (`ImageSidebar`, `ImageOptions`) + `data/ui/image_sidebar.blp` | — | page/sidebar | **no** — `application.rb`'s comment explicitly defers this; today the background selector is wired straight into the sidebar instead of through an `ImageSidebar` |
| `gradia/ui/image_stack.py` + `data/ui/image_stack.blp` | — | widget (content area) | **no** |
| `gradia/overlay/drop_overlay.py` | `lib/drop_overlay.rb` | overlay | yes |
| `gradia/ui/recent_picker.py` (`RecentFile`) + `data/ui/recent_picker.blp` | `lib/recent_picker.rb` | widget/popover | yes |
| `gradia/ui/recent_picker.py` (`ShadowedImageCard`) | `lib/shadowed_image_card.rb` | widget | yes |

## Image pipeline (loaders / exporters / processing)

| Upstream file | → `lib/*.rb` | Kind | Exists |
|---|---|---|---|
| `gradia/ui/image_loaders.py` (`BaseImageLoader`) | — | backend | **no** |
| `gradia/ui/image_loaders.py` (`ScreenshotImageLoader`) | `lib/screenshot_portal.rb` | backend (portal) | yes — the one loader class ported, via the `ashpd` gem |
| `gradia/ui/image_loaders.py` (`FileDialogImageLoader`, `DragDropImageLoader`, `ClipboardImageLoader`, `CommandlineLoader`, `SourceImageLoader`, `ImportManager`) | — | backend | **no** |
| `gradia/ui/image_exporters.py` (`SystemNotifier`, `BaseImageExporter`, `FileDialogExporter`, `ClipboardExporter`, `CommandLineExporter`, `CloseHandlerExporter`, `ExportManager`) | — | backend | **no** |
| `gradia/graphics/image.py` (`ImageBackground`) | `lib/image_background.rb` | backend | yes |
| `gradia/graphics/image.py` (`ImageSelector`) + `data/ui/selectors/image_selector.blp` | `lib/image_selector.rb` | widget | yes |
| `gradia/graphics/image_processor.py` | `lib/image_processor.rb` | backend | yes |
| `gradia/graphics/loaded_image.py` (`ImageOrigin`) | `lib/loaded_image.rb` | backend | yes |
| `gradia/utils/std_image_loader.py` | `lib/std_image_loader.rb` | backend | yes |
| `gradia/clipboard.py` | `lib/clipboard.rb` | backend | yes |
| `gradia/utils/timestamp_filename.py` | `lib/timestamp_filename.rb` | backend | yes |
| `gradia/ui/dialog/delete_screenshots_dialog.py` | `lib/delete_screenshots_dialog.rb` | dialog | yes |
| `gradia/ui/dialog/confirm_close_dialog.py` + `data/ui/confirm_close_dialog.blp` | `lib/confirm_close_dialog.rb` | dialog | yes |

## Backgrounds / gradients / solids

| Upstream file | → `lib/*.rb` | Kind | Exists |
|---|---|---|---|
| `gradia/graphics/background.py` | `lib/background.rb` | backend | yes |
| `gradia/graphics/gradient.py` (+ `gradient_gen.c` via FFI) | `lib/gradient.rb` | backend | yes |
| `gradia/graphics/gradient_selector.py` + `data/ui/selectors/gradient_selector.blp` | `lib/gradient_selector.rb` | widget | yes |
| `gradia/ui/widget/gradient_editor.py` | `lib/gradient_editor.rb` | widget | yes |
| `gradia/ui/widget/gradient_step_dialog_button.py` + `data/ui/gradient_step_dialog.blp` | `lib/gradient_step_dialog.rb` | dialog | yes |
| `gradia/graphics/solid.py` (`SolidBackground`) | `lib/solid_background.rb` | backend | yes |
| `gradia/graphics/solid.py` (`ColorPresetButton`) + `data/ui/selectors/solid_selector.blp` | `lib/solid_selector.rb` | widget | yes |
| `gradia/ui/widget/preset_button.py` | `lib/preset_button.rb` | widget | yes |
| `gradia/ui/widget/quick_color_picker.py` (`ColorPickerMixin`, `QuickColorPicker`, `SimpleColorPicker`) | — | widget | **no** |
| `gradia/ui/widget/toggle_group.py` | `lib/toggle_group.rb` | widget | yes |
| `gradia/ui/widget/background_aspect_ratio_selector.py` | `lib/aspect_ratio_selector.rb` | widget | yes |
| `gradia/ui/widget/aspect_ratio_button.py` | `lib/aspect_ratio_button.rb` | widget | yes |
| `gradia/utils/aspect_ratio.py` | `lib/aspect_ratio.rb` | backend | yes |
| `gradia/utils/colors.py` | `lib/color_conversions.rb` | backend | yes |
| `gradia/ui/widget/font_dropdown.py` | `lib/font_dropdown.rb` | widget | yes |
| `gradia/ui/widget/angle_selector.py` | `lib/angle_selector.rb` | widget | yes |

## Drawing / annotation overlay

| Upstream file | → `lib/*.rb` | Kind | Exists |
|---|---|---|---|
| `gradia/overlay/drawing_actions.py` (`DrawingMode` enum + action list) | `lib/drawing_actions.rb` | backend | yes |
| `gradia/overlay/drawing_overlay.py` (`DrawingOverlay`, `ResizeHandle`) | — | overlay | **no** — the actual canvas widget that drawing actions operate on |
| `gradia/overlay/crop_overlay.py` (`CropOverlay`) | — | overlay | **no** |
| `gradia/overlay/zoom_controller.py` (`ZoomController`) | — | controller | **no** |
| `gradia/overlay/text_entry_popover.py` + `data/ui/text_entry_popover.blp` | `lib/text_entry_popover.rb` | widget/popover | yes |
| `gradia/overlay/transparency_overlay.py` | `lib/transparency_background.rb` | overlay | yes |
| `gradia/ui/widget/drawing_tools_grid.py` | `lib/drawing_tools_grid.rb` | widget | yes |
| `gradia/ui/drawing_tools_group.py` + `data/ui/drawing_tools_group.blp` | — | widget (toolbar group) | **no** — distinct from `drawing_tools_grid.py`, which *is* ported |
| `gradia/backend/tool_config.py` (`ToolOption`) | `lib/tool_config.rb` | backend | yes |

## Pin / overlay window, OCR, source-image generation

| Upstream file | → `lib/*.rb` | Kind | Exists |
|---|---|---|---|
| `gradia/ui/pin_window.py` | `lib/pin_window.rb` | window | yes |
| `gradia/backend/ocr.py` (`OCRModel`) | `lib/ocr.rb` | backend | yes |
| `gradia/ui/dialog/ocr_dialog.py` + `data/ui/ocr_dialog.blp` | — | dialog | **no** |
| `gradia/ui/dialog/ocr_launcher.py` | — | backend (launcher helper) | **no** |
| `gradia/ui/preferences/ocr_model_page.py` + `data/ui/preferences/ocr_model_page.blp` | — | page | **no** |
| `gradia/ui/image_creation/source_image_generator.py` (`SourceExporter`, `ResizeHandle`, `DragController`, `ResizableContainer`, `SourceViewManager`, `LanguageManager`, `StyleManager`, `FakeWindowManager`, `SourceImageGeneratorWindow`) + `data/ui/image_generator_window.blp` | — | window | **no** |

## Preferences

| Upstream file | → `lib/*.rb` | Kind | Exists |
|---|---|---|---|
| `gradia/ui/preferences/preferences_window.py` (`PreferencesWindow`) + `data/ui/preferences_window.blp` | — | window (`Adw.PreferencesDialog`) | **no** |
| `gradia/ui/preferences/preferences_window.py` (`ScreenshotGuidePage`) + `data/ui/preferences/screenshot_guide_page.blp` | — | page | **no** |
| `gradia/ui/preferences/provider_selection_window.py` (`ProviderListPage`) + `data/ui/preferences/provider_list_page.blp` | — | page | **no** |
| `gradia/ui/preferences/provider_selection_window.py` (`CustomProviderPage`) + `data/ui/preferences/custom_provider_page.blp` | — | page | **no** |
| `gradia/ui/preferences/provider_selection_window.py` (`ProviderDetailPage`) + `data/ui/preferences/provider_detail_page.blp` | — | page | **no** |
| `gradia/ui/provider_selection_window.py` (top-level `ProviderListPage`/`CustomProviderPage`/`ProviderDetailPage`) | — | *(dead code upstream)* | n/a — unused duplicate; nothing imports it (`gradia/ui/window.py` and `preferences_window.py` both import `gradia.ui.preferences.provider_selection_window` instead). Do not port this file; port `ui/preferences/provider_selection_window.py` when the preferences window is built |

## Backend / support (non-widget)

| Upstream file | → `lib/*.rb` | Kind | Exists |
|---|---|---|---|
| `gradia/backend/settings.py` + gschema | `lib/settings.rb` | backend | yes |
| `gradia/backend/logger.py` | `lib/logger.rb` | backend | yes |
| `gradia/app_constants.py` + `gradia/constants.in` | `lib/app_constants.rb` | backend | yes |
| `gradia/backend/__init__.py`, `gradia/graphics/__init__.py`, `gradia/overlay/__init__.py`, `gradia/ui/__init__.py`, `gradia/utils/__init__.py`, `gradia/__init__.py` | — | package marker | n/a, not components |
| `gradia/graphics/gradient_gen.c` | consumed by `lib/gradient.rb` via FFI | backend (C extension) | yes (wrapped, not re-implemented) |

## Totals

- Upstream user-facing/component-bearing files (Python classes + their `.blp`): **44** Python files map to roughly **64** distinct classes across them, plus **24** `.blp` templates.
- `ruby` branch: **38** ported component/support files under `lib/` (excluding `gradia.rb`, `gradia/rb.rb`, `gradia/rb/version.rb`), covering the welcome page, sidebar background selector, every background/gradient/solid selector and editor, drawing-tool chrome (grid, actions, text popover, transparency, drop target), recent picker, pin window, screenshot portal, settings, logger, and the About/Shortcuts dialogs end to end.
- **Not yet ported** (window class, image stack/sidebar containers, drawing/crop overlays + zoom controller, OCR dialog/launcher/preferences page, source-image-generator window, image import/export managers, quick color picker, drawing-tools-group toolbar wrapper, and the whole preferences window + its three provider-selection pages). These are the components still needed for `component-parity`.
- Dependency-wiring check for this pass (`ashpd`, `soup3`): unaffected by this survey since no app code was written; `lib/screenshot_portal.rb` already requires and calls `ashpd` for the one portal action that is live (`screenshot`), and nothing under `lib/` currently needs `soup3` (no network/provider code is ported yet — the provider-selection pages above are exactly where it will be needed once built).
