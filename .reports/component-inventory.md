# Gradia — upstream component inventory

Upstream: `origin/main` (Python + PyGObject + blueprint, app id `be.alexandervanhee.gradia`).
Port: the `ruby` branch. Survey only — no app code written in this step.

Upstream totals: 23 `.blp` files, 62 `.py` files, 21 blueprint template roots,
28 GSettings keys in one schema, 18 `po/` catalogues, 66 entries in `po/POTFILES.in`.

## What the port has today

`lib/` on `ruby` now holds 25 flat files plus the skeleton application:

| File | Covers |
|---|---|
| `lib/gradia.rb` | the library entry point — `require_relative` for every ported file |
| `lib/gradia/application.rb` | `Gradia::Application` — still the skeleton window (`Gtk::Application` + `Adwaita::ToolbarView` + `Adwaita::HeaderBar` + placeholder `Adwaita::StatusPage`) |
| `lib/gradia/rb/version.rb` | version constant |
| model layer | `app_constants.rb`, `aspect_ratio.rb`, `background.rb`, `colors.rb`, `drawing_actions.rb`, `gradient.rb`, `image_background.rb`, `loaded_image.rb`, `settings.rb`, `solid_background.rb`, `timestamp_filename.rb`, `tool_config.rb` |
| managers / plumbing | `clipboard.rb`, `logger.rb`, `std_image_loader.rb`, `style.rb` |
| widgets and dialogs | `about_dialog.rb`, `angle_selector.rb`, `app_menu.rb`, `drop_overlay.rb`, `recent_picker.rb`, `shadowed_image_card.rb`, `shortcuts_dialog.rb`, `toggle_group.rb` |

So the model layer, the app menu and the welcome-page widgets are in. **The
editor itself is not**: the main window, the image stack, the sidebar, every
background selector, the drawing tools, every overlay, every preference page,
the Source Snippets window, the pin window, the loaders and the exporters are
all still missing. `lib/welcome_page.rb` is absent too, so the ported
`recent_picker` / `shadowed_image_card` / `drop_overlay` have nothing assembling
them, and `lib/gradia/application.rb` still shows the placeholder status page.

Note on layout: the house shape is one upstream source file to one
`lib/<thing>.rb`, flat (as in the `gnome-contacts-rb` pilot). The ported files
follow that; the application skeleton still sits at `lib/gradia/application.rb`
and should move to `lib/application.rb` when the real application class replaces
it.

## Component map

Kinds: `application`, `window`, `page`, `dialog`, `widget`, `row`, `overlay`,
`menu`, `model`, `manager`, `resource`.

| # | Upstream file(s) | → port file | Kind | Exists |
|---:|---|---|---|---|
| 1 | `gradia/main.py`, `gradia/gradia.in` | `lib/application.rb` | application | partial (skeleton) |
| 2 | `gradia/ui/window.py` + `data/ui/main_window.blp` | `lib/main_window.rb` | window | no |
| 3 | `data/ui/image_sidebar.blp` (`menu app_menu`), `data/ui/welcome_page.blp` (`menu app_menu`) | `lib/app_menu.rb` | menu | yes |
| 4 | `gradia/ui/ui_parts.py` (`AboutDialog`) | `lib/about_dialog.rb` | dialog | yes |
| 5 | `gradia/ui/ui_parts.py` (`ShortcutsDialog`) | `lib/shortcuts_dialog.rb` | dialog | yes |
| 6 | `gradia/ui/welcome_page.py` + `data/ui/welcome_page.blp` | `lib/welcome_page.rb` | page | no |
| 7 | `gradia/ui/recent_picker.py` + `data/ui/recent_picker.blp` | `lib/recent_picker.rb` | widget + error state | yes |
| 8 | `gradia/ui/recent_picker.py` (`ShadowedImageCard`) | `lib/shadowed_image_card.rb` | widget | yes |
| 9 | `gradia/ui/image_stack.py` + `data/ui/image_stack.blp` | `lib/image_stack.rb` | widget (editor canvas + OSD controls) | no |
| 10 | `gradia/ui/image_sidebar.py` + `data/ui/image_sidebar.blp` | `lib/image_sidebar.rb` | widget (sidebar + rows) | no |
| 11 | `gradia/ui/background_selector.py` + `data/ui/background_selector.blp` | `lib/background_selector.rb` | widget | no |
| 12 | `gradia/ui/widget/toggle_group.py` | `lib/toggle_group.rb` | widget | yes |
| 13 | `gradia/graphics/solid.py` + `data/ui/selectors/solid_selector.blp` | `lib/solid_selector.rb` | widget (+ `ColorPresetButton`, `ColorPickerButton`) | no |
| 14 | `gradia/graphics/gradient_selector.py` + `data/ui/selectors/gradient_selector.blp` | `lib/gradient_selector.rb` | widget | no |
| 15 | `gradia/graphics/image.py` (`ImageSelector`) + `data/ui/selectors/image_selector.blp` | `lib/image_selector.rb` | widget | no |
| 16 | `gradia/ui/widget/angle_selector.py` | `lib/angle_selector.rb` | widget (custom-drawn) | yes |
| 17 | `gradia/ui/widget/gradient_editor.py` | `lib/gradient_editor.rb` | widget (+ `GradientColorButton`) | no |
| 18 | `gradia/ui/widget/gradient_step_dialog_button.py` + `data/ui/gradient_step_dialog.blp` | `lib/gradient_step_dialog.rb` | dialog + button + row | no |
| 19 | `gradia/ui/widget/preset_button.py` | `lib/preset_button.rb` | widget (gradient + image presets) | no |
| 20 | `gradia/ui/widget/background_aspect_ratio_selector.py` | `lib/aspect_ratio_selector.rb` | row + popover | no |
| 21 | `gradia/ui/widget/aspect_ratio_button.py` | `lib/aspect_ratio_button.rb` | widget + popover | no |
| 22 | `gradia/ui/drawing_tools_group.py` + `data/ui/drawing_tools_group.blp` | `lib/drawing_tools_group.rb` | widget | no |
| 23 | `gradia/ui/widget/drawing_tools_grid.py` | `lib/drawing_tools_grid.rb` | widget | no |
| 24 | `gradia/ui/widget/quick_color_picker.py` | `lib/quick_color_picker.rb` | widget (+ `SimpleColorPicker`) | no |
| 25 | `gradia/ui/widget/font_dropdown.py` | `lib/font_dropdown.rb` | widget | no |
| 26 | `gradia/overlay/drawing_overlay.py` | `lib/drawing_overlay.rb` | overlay | no |
| 27 | `gradia/overlay/drawing_actions.py` | `lib/drawing_actions.rb` | model (11 action classes + `DrawingMode`) | yes |
| 28 | `gradia/overlay/crop_overlay.py` | `lib/crop_overlay.rb` | overlay | no |
| 29 | `gradia/overlay/zoom_controller.py` | `lib/zoom_controller.rb` | overlay | no |
| 30 | `gradia/overlay/transparency_overlay.py` | `lib/transparency_background.rb` | overlay | no |
| 31 | `gradia/overlay/drop_overlay.py` | `lib/drop_overlay.rb` | overlay + empty state | yes |
| 32 | `gradia/overlay/text_entry_popover.py` + `data/ui/text_entry_popover.blp` | `lib/text_entry_popover.rb` | widget | no |
| 33 | `gradia/ui/dialog/confirm_close_dialog.py` + `data/ui/confirm_close_dialog.blp` | `lib/confirm_close_dialog.rb` | dialog | no |
| 34 | `gradia/ui/dialog/delete_screenshots_dialog.py` | `lib/delete_screenshots_dialog.rb` | dialog | no |
| 35 | `gradia/ui/dialog/ocr_dialog.py` + `data/ui/ocr_dialog.blp` | `lib/ocr_dialog.rb` | dialog (+ loading / no-text / text states) | no |
| 36 | `gradia/ui/dialog/ocr_launcher.py` | `lib/ocr_launcher.rb` | manager | no |
| 37 | `gradia/ui/preferences/preferences_window.py` + `data/ui/preferences_window.blp` | `lib/preferences_window.rb` | dialog | no |
| 38 | `gradia/ui/preferences/preferences_window.py` (`ScreenshotGuidePage`) + `data/ui/preferences/screenshot_guide_page.blp` | `lib/screenshot_guide_page.rb` | page | no |
| 39 | `gradia/ui/preferences/ocr_model_page.py` + `data/ui/preferences/ocr_model_page.blp` | `lib/ocr_model_page.rb` | page (+ no-results state) | no |
| 40 | `gradia/ui/preferences/provider_selection_window.py` (`ProviderListPage`) + `data/ui/preferences/provider_list_page.blp` | `lib/provider_list_page.rb` | page (+ loading / error states) | no |
| 41 | `gradia/ui/preferences/provider_selection_window.py` (`ProviderDetailPage`) + `data/ui/preferences/provider_detail_page.blp` | `lib/provider_detail_page.rb` | page | no |
| 42 | `gradia/ui/preferences/provider_selection_window.py` (`CustomProviderPage`) + `data/ui/preferences/custom_provider_page.blp` | `lib/custom_provider_page.rb` | page | no |
| 43 | `gradia/ui/image_creation/source_image_generator.py` + `data/ui/image_generator_window.blp` | `lib/source_image_generator.rb` | window (+ `ResizeHandle`, `ResizableContainer`, style/language/fake-window managers) | no |
| 44 | `gradia/ui/pin_window.py` | `lib/pin_window.rb` | window | no |
| 45 | `gradia/ui/image_exporters.py` | `lib/image_exporters.rb` | manager (save dialog, clipboard, upload command, close handler, notifications) | no |
| 46 | `gradia/ui/image_loaders.py` | `lib/image_loaders.rb` | manager (file dialog, drop, clipboard, screenshot portal, stdin, snippet) | no |
| 47 | `gradia/graphics/image_processor.py` | `lib/image_processor.rb` | model | no |
| 48 | `gradia/graphics/background.py` | `lib/background.rb` | model | yes |
| 49 | `gradia/graphics/gradient.py` | `lib/gradient.rb` | model | yes |
| 50 | `gradia/graphics/solid.py` (`SolidBackground`) | `lib/solid_background.rb` | model | yes |
| 51 | `gradia/graphics/image.py` (`ImageBackground`) | `lib/image_background.rb` | model | yes |
| 52 | `gradia/graphics/loaded_image.py` | `lib/loaded_image.rb` | model | yes |
| 53 | `gradia/backend/settings.py` + `data/be.alexandervanhee.gradia.gschema.xml` | `lib/settings.rb` | model (28 GSettings keys) | yes |
| 54 | `gradia/backend/tool_config.py` | `lib/tool_config.rb` | model | yes |
| 55 | `gradia/backend/ocr.py` | `lib/ocr.rb` | manager | no |
| 56 | `gradia/backend/logger.py` | `lib/logger.rb` | manager | yes |
| 57 | `gradia/clipboard.py` | `lib/clipboard.rb` | manager | yes |
| 58 | `gradia/app_constants.py` | `lib/app_constants.rb` | model (gradient/image presets) | yes |
| 59 | `gradia/utils/aspect_ratio.py` | `lib/aspect_ratio.rb` | model | yes |
| 60 | `gradia/utils/colors.py` | `lib/colors.rb` | model | yes |
| 61 | `gradia/utils/timestamp_filename.py` | `lib/timestamp_filename.rb` | model | yes |
| 62 | `gradia/utils/std_image_loader.py` | `lib/std_image_loader.rb` | manager | yes |
| 63 | `data/style.css` | `lib/style.rb` | resource (CSS provider, ~45 app classes) | yes |
| 64 | `data/models.json`, `data/screenshot_folder_names.json`, `data/help.txt`, `data/source-styles/*.xml`, `data/images/*`, `data/icons/scalable/actions/*.svg` (41 icons), `data/fonts/Caveat` | `data/` in the fork | resource | yes |
| 65 | `po/LINGUAS` (18 locales), `po/POTFILES.in` (66 files), `po/gradia.pot` | `po/` in the fork | resource | no |

`gradia/ui/provider_selection_window.py` is a stale duplicate of
`gradia/ui/preferences/provider_selection_window.py` (same three classes, same
`__gtype_name__`s); `gradia/ui/window.py` imports the one under
`preferences/`. Only the `preferences/` copy is ported.

`gradia/graphics/gradient_gen.c` is a C helper for gradient rasterisation; it is
not a component, and the Ruby port renders gradients with Cairo instead.

## Detail by unit

### `gradia/ui/window.py` + `data/ui/main_window.blp` — the editor window

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` (`GradiaMainWindow`) | 1 | `devel` (debug builds only) | `close-request`, `notify::focus-widget` | 975×675; broken in Ruby bindings — use `Gtk::ApplicationWindow` |
| `Adw.ToastOverlay` | 1 | — | — | every notification in the app lands here |
| `Adw.ToolbarView` | 1 | — | — | `top-bar-style: flat`, switched to `raised` once an image loads |
| `Gtk.Stack` `main_stack` | 1 | — | — | crossfade 200ms, pages `welcome` / `main` |
| `Adw.Bin` `welcome_page` | 1 | — | — | holds `WelcomePage` |
| `Adw.BreakpointBin` + `Adw.Breakpoint` | 1 | — | `max-width: 695sp` → `split_view.collapsed`, `image_bin.compact` | |
| `Adw.OverlaySplitView` | 1 | — | — | sidebar 300px wide, hidden until an image loads |

**Actions installed on `win.`** (41, all built through `create_action`, so a
scan finds none of them):

| Action | Accel | Enabled at start |
|---|---|---|
| `shortcuts` | `<Primary>question` | yes |
| `about` | — | yes |
| `donate` | — | yes |
| `quit` | `<Primary>q`, `<Primary>w` | yes |
| `open` | `<Primary>o` | yes |
| `create-source-image` | `<Primary>p` | yes |
| `load-drop` (`s`) | — | yes |
| `paste` | `<Primary>v` | yes |
| `screenshot` | `<Primary>a` | yes |
| `open-path` (`s`) | — | yes |
| `tool-option-changed` (`s`) | — | yes |
| `del-selected` | `<Primary>x`, `Delete` | yes |
| `open-folder` | — | **no** |
| `save` | `<Primary>s` | **no** |
| `copy` | `<Primary>c` | **no** |
| `command` | `<Primary>m` | yes |
| `aspect-ratio-crop` (`d`) | — | yes |
| `crop` | `<Primary>r` | yes |
| `crop-back` | `Escape` | yes |
| `reset-crop` | `<Primary><Shift>r` | yes |
| `sidebar-shown` (`b`) | — | yes |
| `toggle-sidebar` | `F9` | yes |
| `ocr` | `<Primary>o` | yes (stateful) |
| `zoom-in` | `<Control>plus`, `<Control>equal`, `<Control>KP_Add` | yes |
| `zoom-out` | `<Control>minus`, `<Control>KP_Subtract` | yes |
| `reset-zoom` | `<Control>0`, `<Control>KP_0` | yes |
| `pan-left` / `pan-right` / `pan-up` / `pan-down` | `<Control>Left/Right/Up/Down` | yes |
| `set-drawing-mode-<mode>` × 11 | per-mode (`0 S`, `1 P`, `2 T`, `3 L`, `4 A`, `5 R`, `6 O`, `7 H`, `8 C`, `9 N`) | yes, suppressed while an entry has focus |
| `undo` | `<Primary>z` | **no** |
| `redo` | `<Primary><Shift>z` | **no** |
| `clear` | — | yes |
| `draw-mode` (`s`) | — | yes |
| `delete-screenshots` | `<Primary><Shift>d` | **no** |
| `preferences` | `<Primary>comma` | yes |
| `set-screenshot-folder` (`s`) | — | yes |

Accelerators for the drawing-mode actions are **removed and restored** as focus
enters and leaves a `Gtk.Entry` / `Gtk.TextView` / `Gtk.SearchEntry` / editable
`Gtk.Text` — a behaviour no `.blp` shows, and easy to lose in a port.

**Actions installed on `app.`** (`gradia/main.py`): `pin` (`s`), `open` (`s`).
CLI flags: `--help`, `--pin`, `--screenshot-file=`, `--ocr-file=`, plus file
arguments and an image on stdin.

### `data/ui/image_stack.blp` + `gradia/ui/image_stack.py` — the canvas

Three OSD control clusters over the picture, all revealer-gated:

| Widget | × | CSS | Action | Notes |
|---|---:|---|---|---|
| `Gtk.Revealer` | 9 | — | — | crop controls, sidebar, crop button, OCR, erase, crop options, confirm, right controls, zoom info |
| `Gtk.Box` | 6 | `osd-box` (3) | — | left / middle / right clusters |
| `Gtk.Button` | 11 | `flat` (9), `back-button`, `suggested-action pill confirm-pill` | `win.crop-back`, `win.sidebar-shown(true)`, `win.crop`, `win.ocr`, `win.del-selected`, `win.reset-crop`, `win.reset-zoom`, `win.zoom-out`, `win.zoom-in`, `win.undo`, `win.redo`, `win.clear` | |
| `Adw.HeaderBar` | 1 | `header-osd` | — | `show-title: false`, start title buttons off |
| `Gtk.Stack` | 1 | — | — | pages `loading` / `image` |
| `Adw.Spinner` | 1 | — | — | 48×48 loading state |
| `Gtk.Label` `zoom_label` | 1 | `flat` | — | 5 chars, "100%" |
| `Gtk.Picture` | 1 | — | — | `content-fit: contain` |
| `Gtk.Overlay` | 3 | — | — | main / picture / background |
| app widgets | — | — | — | `DropOverlay`, `ZoomController`, `DrawingOverlay`, `CropOverlay`, `TransparencyBackground`, `AspectRatioButton` |

### `data/ui/image_sidebar.blp` + `gradia/ui/image_sidebar.py` — the sidebar

| Widget | × | CSS | Action | Notes |
|---|---:|---|---|---|
| `Adw.HeaderBar` | 1 | — | — | `centering-policy: loose` |
| `Gtk.Button` | 7 | `circular rotate` (2), `suggested-action pill`, `raised pill`, `raised circular`, `flat` | `win.open`, `win.screenshot`, `win.open-folder`, `win.save`, `win.copy`, `win.command` | rotate buttons have no action — direct signals |
| `Gtk.MenuButton` | 1 | — | `app_menu` | primary |
| `Adw.PreferencesGroup` | 4 | — | — | background slot, Image Options, Current File, (drawing tools is a `Gtk.Box`) |
| `Adw.SpinRow` | 2 | — | — | padding 0–75 step 5 (default 5), corner radius 0–50 (default 2) |
| `Adw.ActionRow` | 5 | `property` (3) | — | shadow, rotation, filename, location, processed size |
| `Gtk.Scale` | 1 | — | — | shadow 0–10, value drawn right |
| `Adw.SwitchRow` | 1 | — | — | Auto Balance |
| `Gtk.Box` (bottom bar) | 1 | `toolbar` | — | save / copy / share |
| app widgets | — | — | — | `DrawingToolsGroup`, `AspectRatioSelector` |

`menu app_menu` — 6 items in 2 sections: Source Snippets
(`win.create-source-image`), Delete Taken Screenshot(s)
(`win.delete-screenshots`) | Preferences (`win.preferences`), Keyboard Shortcuts
(`win.shortcuts`), Donate to Gradia (`win.donate`), About Gradia (`win.about`).
The welcome page carries a **four-item variant** of the same menu (no snippets,
no delete) — two menu definitions, one component.

### `data/ui/welcome_page.blp` — the empty state

`Adw.BreakpointBin` (`max-width: 600sp` → `recent_picker.compact`,
`button_box.orientation: vertical`) → `DropOverlay` → `Adw.ToolbarView` →
`Adw.HeaderBar` (`MenuButton` primary + `Gtk.Button` `win.create-source-image`)
→ `Adw.StatusPage` "Enhance an Image" / "Drag and drop one here" →
`RecentPicker` + two buttons: "Take a Screenshot…" (`pill text-button
suggested-action`, `win.screenshot`) and "Open Image…" (`pill text-button`,
`win.open`).

### `data/ui/recent_picker.blp` — recent screenshots, and its error state

`Gtk.FlowBox` `recent-button-flowbox`, 2–3 per line, homogeneous, selection
none; per-item `Adw.Bin` with `card`, a `recent-button` button whose gradient
background is generated into a `Gtk.CssProvider` at runtime, and
`ShadowedImageCard` (a `Gtk.Widget` with a hand-written `do_snapshot`).
Error overlay: `title-2` "Screenshot Folder Not Found" + "Please set it in the
Preferences menu" + a `pill` button on `win.preferences`.

### `data/ui/drawing_tools_group.blp` — annotation tools

`Gtk.Text` heading (`heading h4`, insensitive) + `DrawingToolsGrid` +
`QuickColorPicker` + `Gtk.Scale` 3–25 (default 14, step 2) + a `Gtk.Revealer`
over a `Gtk.Stack` with four pages — `empty`, `fill` (1 `SimpleColorPicker`),
`fill-border` (2), `text` (2 + `FontDropdown`). `DrawingToolsGrid` is a
`Gtk.Grid` of `Gtk.ToggleButton`s, `flat` normally and `accent` when selected,
one per `DrawingMode` — a repeater of 11.

### `data/ui/preferences_window.blp` — preferences

`Adw.PreferencesDialog` 600×500, one page, 6 groups:
Screenshots (recent-directory `Adw.ActionRow` with a `dim-label` value and
`go-next-symbolic`), a `Adw.ButtonRow` "Screenshot Shortcut" pushing
`ScreenshotGuidePage`, Save Options (`Adw.ComboRow` image format, from a
`Gtk.StringList`), Closing (`Adw.ComboRow` "When Exiting" — Ask for
Confirmation / Copy and Close / Close Instantly — plus two `Adw.SwitchRow`s),
Image Upload Providers (provider `Adw.ActionRow` pushing `ProviderListPage`, and
a confirm-on-upload `Adw.SwitchRow`), Text Extraction (bound to
`template.ocr_enabled`, pushes `OCRModelPage`). Toast "Copied!" on the guide
page's two read-only `monospace` entries.

### Dialogs and their states

| Dialog | Type | Responses / states |
|---|---|---|
| `ConfirmCloseDialog` | `Adw.AlertDialog` | Cancel / Copy / Close (destructive); extra child is a `boxed-list` `Gtk.ListBox` with a "Don't Ask Again" `Adw.ActionRow` + `Gtk.CheckButton` |
| `DeleteScreenshotsDialog` | `Adw.AlertDialog` | Cancel / Trash (destructive); singular and plural heading+body; extra child lists every file in a `boxed-list`; "No screenshots to delete" toast when empty |
| `OCRDialog` | `Adw.Dialog` 700×500 | `Adw.ViewStack`-style `Gtk.Stack`: `loading` (`Adw.Spinner` 48), `no-text` (`Adw.StatusPage` "No Text Found" / "Please make a new selection"), `text` (selectable wrapped `Gtk.Label` + a `suggested-action circular semi-transparent` copy button); language `MenuButton` in the header |
| `CssGradientDialog` | `Adw.Dialog` 400×420 | gradient preview `card` frame, `Adw.PreferencesGroup` "Gradient Steps" / "You can add up to five steps", `suggested-action` Add Step button, repeater of `GradientStepRow` (`Gtk.ColorButton` + `Gtk.SpinButton` + `destructive-action` remove) |
| `AboutDialog` | `Adw.AboutDialog` | 2 acknowledgement sections ("Code and Design Borrowed from", "Image Sources"), developers, designers, translator-credits, GPL-3.0 |
| `ShortcutsDialog` | `Adw.ShortcutsDialog` (libadwaita ≥ 1.8) **or** `Gtk.ShortcutsWindow` fallback | 5 sections / 37 items: File Actions (6), Annotations (13), Cropping (2), Zooming (7), General (5) |
| Confirm Upload | `Adw.AlertDialog` built inline in `window.py` | Cancel / Upload (suggested) |
| Provider picker (no command set) | `Adw.PreferencesDialog` built inline in `window.py` | pushes `ProviderListPage` with `can_pop=False` |
| OCR model prompt | `Adw.PreferencesDialog` built inline in `ocr_launcher.py` | pushes `OCRModelPage` with `can_pop=False` |

### Preference subpages

| Page | Root | States |
|---|---|---|
| `ScreenshotGuidePage` | `Adw.NavigationPage` | one scrolled `Adw.Clamp`; `title-1`, markup instructions, two `title-4`+`caption dimmed` blocks, two read-only `monospace` `Gtk.Entry`s with a copy secondary icon; a third ("Delayed Screenshot") is `visible: false` |
| `OCRModelPage` | `Adw.NavigationPage` | `SearchBar`+`SearchEntry`; `Gtk.Stack`: `list` (`boxed-list` `Gtk.ListBox`, repeater over models) / `empty` (`Adw.StatusPage` "No Results Found") |
| `ProviderListPage` | `Adw.NavigationPage` | `Adw.ViewStack`: `loading` (`Adw.Spinner`), `error` (`Adw.StatusPage` "An error occurred" / "Please try again later"), `content` (`Adw.PreferencesPage` + repeater of provider rows) |
| `ProviderDetailPage` | `Adw.NavigationPage` | `Gtk.Picture` 48², `title-2` + `dim-label`, `suggested-action pill` Select; About group with Homepage / Terms of Service rows (both `visible: false` until data); Features group (repeater); Upload Command group (`visible: false`) with a `monospace` label in a horizontal scroller |
| `CustomProviderPage` | `Adw.NavigationPage` | `Save` button, insensitive until edited; `GtkSource.View` + `GtkSource.Buffer` with `provider-source-view` |

### `data/ui/image_generator_window.blp` — Source Snippets

`Adw.Window` 700×600 (min 625×400): header bar, an `Adw.Clamp` of two
`Adw.PreferencesGroup`s — Language (`Gtk.DropDown` with search, `flat-dropdown`)
and Style (`Gtk.MenuButton` → `Gtk.Popover` → `Gtk.FlowBox` of style previews),
Window Frame and Line Numbers `Gtk.Switch`es — a `Gtk.ScrolledWindow` holding
the resizable source view, and a `suggested-action pill` Export button.
Source code: `ResizeHandle`, `DragController`, `ResizableContainer`,
`SourceViewManager`, `LanguageManager`, `StyleManager`, `FakeWindowManager`,
`SourceExporter`.

### `gradia/ui/pin_window.py` — the pinned screenshot window

`Adw.ApplicationWindow`, non-resizable, min 20×20, sized to ≤50% of the monitor;
`Gtk.WindowHandle` → `Adw.ToolbarView` (`extend-content-to-top-edge`) →
`Adw.HeaderBar` `header-osd` with no title + `Gtk.Picture`. Two
`Adw.TimedAnimation`s on `opacity` (1.0→0.25 over 200ms ease-out-cubic on enter,
0.25→1.0 over 350ms ease-in-cubic on leave) driven by a
`Gtk.EventControllerMotion`. Prints `GRADIA_PIN_READY` when loaded.

### Toasts and notifications (the error and success surface)

`win._show_notification` → `Adw.Toast`, optionally with a button. Messages:
Unsupported image file extension, Image Saved, Export Failed, No processed image
available, Image Copied, Failed to copy image to clipboard, Link generated
successfully (+ "Open Link" button), Custom command failed: …, Warning: …,
Result copied to clipboard, No output from command, Failed to run custom export
command, Not a supported image format (×3), URL is not a supported image format,
Failed to load image from URL., Failed to take screenshot (×2), Screenshot
cancelled, Screenshot captured! (×2), Failed to process screenshot, Failed to
load screenshot, Source snippet Generated!, No screenshots to delete, Screenshot
moved to trash / Screenshots moved to trash, Copied! (×2).
Desktop `Gio.Notification`s: "Close Operation Failed" / "Failed to export image"
(`dialog-error`), "Image Copied" / "You can now paste it from the clipboard."

### Stylesheet

`data/style.css` defines ~45 app-specific classes that the port must reproduce,
none of which libadwaita provides: `preset-button`, `provider-source-view`,
`gradient-color-picker`, `simple-color-picker`, `gradient-color-button`,
`gradient-editor`, `gradient-background`, `angle-entry`, `monospace`,
`recent-button`, `recent-button-flowbox`, `bold`, `window-border`,
`title-entry`, `no-highlights`, `sourceview`, `rotate`, `flat-dropdown`,
`color-button`, `color-hover-bg`, `checkmark-icon`, `dark`, `visible`,
`transparent-simple-color-picker`, `transparent-color-button`,
`transparent-color-button-small`, `color-picker-button`,
`drop-overlay-status-page`, `osd-box`, `header-osd`, `back-button`,
`confirm-pill`, `symbolic-circular`, `rounded-top`, `semi-transparent`,
plus `:root` custom properties and four media-query overrides (dark, more
contrast, dark+more contrast) and `GtkSourceStyleSchemePreview` rules.
Several classes are attached from code only (`accent` on the selected tool,
`selected` on a gradient stop, `visible` on a checkmark, `devel` on the window,
`view` on the image stack, `card` on a recent item) and no `.blp` names them.

## Blockers

1. **`Adwaita::ApplicationWindow` is broken in the Ruby bindings** — upstream's
   main window, pin window and `Adw.Window` snippet window all need
   `Gtk::ApplicationWindow` / `Gtk::Window` instead, with the Adwaita content
   inside.
2. **Custom-drawn `Gtk.Widget` subclasses.** `AngleSelector`, `CropOverlay`,
   `ZoomController`, `TransparencyBackground` and `ShadowedImageCard` subclass
   `Gtk.Widget` and implement `do_snapshot` / `do_measure` / `do_size_allocate`.
   ruby-gnome cannot override those vfuncs; each has to be rebuilt on
   `Gtk::DrawingArea` (or a `Gtk::Fixed`/`Gtk::Overlay` composition) with Cairo
   drawing, which changes the measure and allocate behaviour and needs its own
   layout decisions.
3. **`Xdp` (libportal) has no Ruby binding.** `ScreenshotImageLoader` uses
   `Xdp.Portal` with `ScreenshotFlags.INTERACTIVE`; `win.screenshot` and
   `--screenshot-file=` depend on it. Needs a shelling-out fallback
   (`gnome-screenshot`, `grim`, the portal over D-Bus) or the feature is
   degraded.
4. **`GtkSource` 5 may be absent from the dev shell.** `CustomProviderPage` and
   the whole Source Snippets window are built on `GtkSource.View`/`Buffer` and
   three bundled style schemes. Confirm `gtksourceview5` and its `.gir` are in
   `flake.nix` before planning units 42–43.
5. **Image processing has no Pillow.** `ImageProcessor`, `LoadedImage`,
   `BalancedPadding` and every exporter assume PIL (resize, crop, rotate,
   shadow, auto-balance, format conversion). The port needs Cairo +
   GdkPixbuf equivalents, and `gradient_gen.c` (a C gradient rasteriser) has to
   become Cairo pattern code.
6. **OCR needs tesseract and downloadable traineddata.** `gradia/backend/ocr.py`
   plus `data/models.json` (42KB catalogue) drive `OCRDialog` and
   `OCRModelPage`; without tesseract in the shell those two units cannot be
   driven.
7. **`Adw.ShortcutsDialog` needs libadwaita ≥ 1.8** and upstream itself falls
   back to `Gtk.ShortcutsWindow`. Check which the dev shell's libadwaita offers
   and whether the Ruby bindings expose `Adwaita::ShortcutsDialog`,
   `ShortcutsSection` and `ShortcutsItem`.
8. **GObject properties and custom signals.** `DropOverlay` (`title`,
   `drop-target`, `child-widget`), `ToggleGroup` (`active-name`),
   `AspectRatioSelector`, `FontDropdown`, `DrawingToolsGrid`, `AngleSelector`,
   `QuickColorPicker`, `SimpleColorPicker` all declare `GObject.Property` or
   `__gsignals__` and the `.blp` binds to them (`notify::active-name`,
   `ratio-changed`, `tool-changed`, `color-changed`, `font-changed`,
   `angle-changed`). The Ruby port has to replace these with plain callbacks,
   which changes how the parent wires every one of them.
9. **GSettings schema.** 28 keys in one schema with `@APP_ID@` substituted at
   build time. The port needs its own compiled schema (or a JSON-backed
   `Settings` as the contacts pilot does) before preferences, tool config,
   background state or exit behaviour can round-trip.
10. **Translations.** 18 catalogues and 66 `POTFILES.in` entries; `_()` is used
    throughout, including in the `.blp` files. The port has no gettext wiring
    yet, so every string above is currently untranslatable.
