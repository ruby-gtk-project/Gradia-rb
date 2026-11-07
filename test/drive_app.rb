# frozen_string_literal: true

# Drives the window the port opens: the overlay split view, the welcome page in
# its content area, the background selector in its sidebar, the primary menu
# and the dialogs behind it, and every widget those are built from. Also
# drives FontDropdown and TextEntryPopover in a scratch window: both are
# ported but not yet wired into any parent widget by the app itself.
#
# Run with: nix develop --command xvfb-run -a ruby test/drive_app.rb
require 'tmpdir'
require 'fileutils'

ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir
ENV['XDG_CACHE_HOME'] = Dir.mktmpdir

require_relative '../lib/gradia'
require_relative 'gtk_driver'

screenshot_folder = Dir.mktmpdir
# Distinct modification times, so "newest first" has one right answer.
3.times do |index|
  File.join(screenshot_folder, "shot#{index}.png").tap do |path|
    FileUtils.cp(File.join(AppConstants::IMAGES_DIR, 'graph.png'), path)
    File.utime(Time.now - (index * 60), Time.now - (index * 60), path)
  end
end

app = Gradia::Application.new

# A second window for the widgets that are ported but not yet placed on a page
# by any ported parent, so the real window keeps its real contents.
scratch = nil

GtkDriver.drive(app, shots: 'tmp/shots') do |d, _app|
  d.window { app.window }

  d.step('the window opens on the split view') do
    scratch = Gtk::Window.new.tap do |win|
      win.set_default_size(420, 320)
      win.present
    end

    d.check('the scratch window opened') { scratch.visible? }
    d.check('window is visible') { app.window.visible? }
    d.check('title is set') { app.window.title == 'Gradia' }
    d.check('content is the split view') { app.window.content == app.split_view }
    d.check('the welcome page is the content pane') do
      app.split_view.content == app.welcome_page.breakpoint_bin
    end
    d.check('the sidebar holds the background selector') do
      app.background_selector.bin.root == app.window
    end
    d.check('the sidebar starts shown') { app.split_view.show_sidebar? }
    d.check('stylesheet installed') { app.style.provider && app.style.css.include?('recent-button') }
    d.check('app icon resolves') { app.icon_theme.has_icon?(AppConstants::APP_ID) }
    d.check('ported action icons resolve') do
      %w[one-circle-symbolic linear-symbolic aspect-ratio-symbolic fill-symbolic]
        .all? { |name| app.icon_theme.has_icon?(name) }
    end
  end

  d.step('the window renders') { d.shot('01-window') }

  d.step('the window owns the actions the menu and the sidebar drive') do
    %w[about shortcuts donate quit toggle-sidebar sidebar-shown].each do |name|
      d.check(name) { app.window.lookup_action(name) }
    end

    # GTK resolves <primary> to the platform modifier when it stores the
    # accelerator, so this reads back as <Control> on Linux.
    d.check('shortcuts has its accelerator') do
      app.app.get_accels_for_action('win.shortcuts') == ['<Control>question']
    end
    d.check('toggle-sidebar is on F9') do
      app.app.get_accels_for_action('win.toggle-sidebar') == ['F9']
    end
    d.check('the loaders are not ported, so win.open is absent') do
      app.window.lookup_action('open').nil?
    end
  end

  d.step('win.toggle-sidebar and win.sidebar-shown move the sidebar') do
    app.window.lookup_action('toggle-sidebar').activate(nil)
    d.check('toggling hides it') { !app.split_view.show_sidebar? }

    app.window.lookup_action('sidebar-shown').activate(GLib::Variant.new(true))
    d.check('the parameterised action shows it again') { app.split_view.show_sidebar? }
  end

  d.step('win.about opens the About dialog') do
    app.window.lookup_action('about').activate(nil)
  end

  d.step('the About dialog is up and filled in') do
    d.check('a dialog is showing') { !app.window.visible_dialog.nil? }
    d.check('version is the gem version') { app.about_dialog.dialog.version == Gradia::Rb::VERSION }
    d.check('developer name') { app.about_dialog.dialog.developer_name == AboutDialog::DEVELOPER_NAME }
    d.check('licence is GPL 3') { app.about_dialog.dialog.license_type == Gtk::License::GPL_3_0 }
    d.shot('02-about')
    app.window.visible_dialog&.close
  end

  d.step('win.shortcuts opens the shortcuts window') do
    app.window.lookup_action('shortcuts').activate(nil)
  end

  d.step('the shortcuts dialog lists every section') do
    d.check('a dialog is showing') { !app.window.visible_dialog.nil? }
    d.check('five sections') { app.shortcuts_dialog.sections.length == 5 }
    d.check('titles match upstream') do
      app.shortcuts_dialog.sections.map(&:title) == ShortcutsDialog::SECTIONS.keys
    end
    d.shot('03-shortcuts')
    app.window.visible_dialog&.close
  end

  d.step('the welcome page carries the empty state and its buttons') do
    app.welcome_page.then do |page|
      d.check('title') { page.status_page.title == WelcomePage::TITLE }
      d.check('description') { page.status_page.description == WelcomePage::DESCRIPTION }
      d.check('drop overlay title') { page.drop_overlay.title == WelcomePage::DROP_TITLE }
      d.check('drop target attached') { !page.drop_overlay.drop_target.nil? }
      d.check('the menu button is primary') { page.app_menu.button.primary? }
      d.check('menu has four items') { page.app_menu.section.n_items == 4 }
      d.check('screenshot button points at win.screenshot') do
        page.screenshot_button.action_name == 'win.screenshot'
      end
      d.check('and is insensitive, because that action is not ported') do
        !page.screenshot_button.sensitive?
      end
      d.check('open button points at win.open') { page.open_image_button.action_name == 'win.open' }
    end
  end

  d.step('the welcome page fills from a screenshot folder') do
    Settings.new.tap { |settings| settings.screenshot_folder = screenshot_folder }.then do |settings|
      app.welcome_page.recent_picker.instance_variable_set(
        :@image_getter,
        RecentImageGetter.new(settings: settings),
      )
    end
    app.welcome_page.refresh_recent_picker
  end

  d.step('three cards carry thumbnails and three are empty') do
    app.welcome_page.recent_picker.item_grid.then do |grid|
      d.check('six cards in the grid') { grid.children.length == 6 }
      d.check('the first three are sensitive') do
        (0..2).all? { |index| grid.get_child_at_index(index).child.sensitive? }
      end
      d.check('tooltips name the files') do
        grid.get_child_at_index(0).child.tooltip_text == 'shot0.png'
      end
    end
    d.check('no error overlay') { !app.welcome_page.recent_picker.error_overlay.visible? }
  end

  # One extra tick: filling the cards leaves the grid unrealised for a frame,
  # and a screenshot of an unrealised widget has no render node.
  d.step('the welcome page renders') { d.shot('04-welcome-page') }

  d.step('the compact breakpoint narrows the welcome page') do
    app.welcome_page.compact_breakpoint.signal_emit('apply')
    d.check('the picker went compact') { app.welcome_page.recent_picker.compact? }
    d.check('the buttons stacked') { app.welcome_page.button_box.orientation.nick == 'vertical' }

    app.welcome_page.compact_breakpoint.signal_emit('unapply')
    d.check('and back') { !app.welcome_page.recent_picker.compact? }
    d.check('side by side again') { app.welcome_page.button_box.orientation.nick == 'horizontal' }
  end

  d.step('the background selector opens on the stored mode') do
    app.background_selector.then do |selector|
      # A fresh profile has background-mode at its default, which upstream's
      # schema sets to "none" — so the page area starts folded away.
      d.check('none on a fresh profile') { selector.current_mode == 'none' }
      d.check('the page is not revealed') { !selector.stack_revealer.reveal_child? }
      d.check('and there is no background') { selector.current_background.nil? }
      d.check('all three pages exist') do
        %w[solid gradient image].all? { |name| selector.stack.get_child_by_name(name) }
      end
    end
  end

  # Everything the sidebar reports goes through here, so the steps below can
  # assert on what the window would have been handed.
  reported = []

  d.step('switching the mode moves the page and writes the setting') do
    app.background_selector.on_change { |background| reported << background }
    app.background_selector.toggle_group.active_name = 'solid'

    d.check('mode followed') { app.background_selector.current_mode == 'solid' }
    d.check('page followed') { app.background_selector.stack.visible_child_name == 'solid' }
    d.check('the change was reported') { reported.last == app.background_selector.solid }
    d.check('and stored') { Settings.new.background_mode == 'solid' }

    app.background_selector.toggle_group.active_name = 'none'
    d.check('None hides the page') { !app.background_selector.stack_revealer.reveal_child? }
    d.check('and has no background') { app.background_selector.current_background.nil? }

    app.background_selector.toggle_group.active_name = 'solid'
  end

  # The stack crossfades for 250ms, so the page gets a tick of its own to
  # settle before the camera comes out.
  d.step('the solid page settles') { d.check('solid is up') { app.background_selector.stack.visible_child_name == 'solid' } }

  d.step('the solid page renders') { d.shot('05-background-solid') }

  d.step('the solid selector offers fourteen swatches and a chooser') do
    app.background_selector.solid_selector.then do |selector|
      d.check('fourteen swatches') { selector.preset_buttons.length == SolidSelector::COMMON_COLORS.length }
      d.check('the transparent one has no alpha') { selector.preset_buttons.last.alpha.zero? }
      d.check('the chooser is there') { !selector.color_picker_button.nil? }

      reported.clear
      selector.preset_buttons[4].button.signal_emit('clicked')

      d.check('clicking a swatch takes') { selector.solid.color == '#3584e4' }
      d.check('and the sidebar was told') { reported.last == selector.solid }
      d.check('and the stored state followed') do
        Settings.new.solid_state.include?('3584e4')
      end
      d.check('the swatch wears the checkmark') do
        selector.preset_buttons[4].checkmark.css_classes.include?('visible')
      end
    end

    app.background_selector.toggle_group.active_name = 'gradient'
  end

  d.step('the gradient page settles') do
    d.check('gradient is up') { app.background_selector.stack.visible_child_name == 'gradient' }
  end

  # The stack is still crossfading into this page when the window is
  # photographed, so this one frames the group itself.
  d.step('the gradient page renders') do
    d.shot('06-background-gradient', app.background_selector.gradient_selector.group)
  end

  d.step('the gradient selector shows the stored gradient') do
    app.background_selector.gradient_selector.then do |selector|
      d.check('two stops on the bar') { selector.gradient_editor.stop_count == 2 }
      d.check('the mode toggle matches') do
        selector.type_group.active_name == app.background_selector.gradient.gradient.mode
      end
      d.check('the angle entry matches the dial') do
        selector.angle_entry.text == format('%d°', selector.angle_selector.angle)
      end
      d.check('the step dialog button has the gradient') { !selector.step_dialog_button.gradient.nil? }
      d.check('no stop is selected, so the step box is hidden') do
        !selector.button_revealer.reveal_child?
      end
    end
  end

  d.step('typing an angle moves the dial and rebuilds the gradient') do
    app.background_selector.gradient_selector.then do |selector|
      selector.angle_entry.text = '42°'
      selector.angle_entry.signal_emit('activate')

      d.check('the dial followed') { selector.angle_selector.angle == 42 }
      d.check('the entry was normalised') { selector.angle_entry.text == '42°' }
      d.check('the gradient followed') { app.background_selector.gradient.gradient.angle == 42 }

      selector.angle_entry.text = 'wat'
      selector.angle_entry.signal_emit('activate')
      d.check('junk is refused and the dial put back') { selector.angle_entry.text == '42°' }
      d.check('the dial did not move') { selector.angle_selector.angle == 42 }

      # 400 clamps to 360, and the dial keeps its angle modulo a full turn,
      # so 360 reads back as 0 — the same place on the ring.
      selector.angle_entry.text = '400'
      selector.angle_entry.signal_emit('activate')
      d.check('an out-of-range angle is clamped to a full turn') do
        selector.angle_selector.angle.zero?
      end
    end
  end

  d.step('choosing radial disables the angle controls') do
    app.background_selector.gradient_selector.then do |selector|
      selector.type_group.active_name = 'radial'
      d.check('the dial went insensitive') { !selector.angle_selector.drawing_area.sensitive? }
      d.check('and faded') { selector.angle_selector.drawing_area.opacity < 1 }
      d.check('the entry went insensitive') { !selector.angle_entry.sensitive? }
      d.check('the gradient is radial') { app.background_selector.gradient.gradient.mode == 'radial' }

      selector.type_group.active_name = 'linear'
      d.check('and back to sensitive') { selector.angle_selector.drawing_area.sensitive? }
    end
  end

  d.step('clicking the gradient bar adds a stop') do
    app.background_selector.gradient_selector.gradient_editor.then do |editor|
      editor.click_gesture.signal_emit(
        'pressed',
        1,
        (GradientEditor::WIDTH / 2).to_f,
        10.0,
      )
      d.check('three stops now') { editor.stop_count == 3 }
      d.check('the new one is selected') { !editor.selected_button.nil? }
      d.check('the gradient has three steps') do
        app.background_selector.gradient.gradient.steps.length == 3
      end
    end
  end

  d.step('the selected stop shows its position and a remove button') do
    app.background_selector.gradient_selector.then do |selector|
      d.check('the step box is revealed') { selector.button_revealer.reveal_child? }
      d.check('the remove button is revealed') { selector.remove_button_revealer.reveal_child? }
      d.check('the label reads a percentage') { selector.step_label.label.end_with?('%') }
      d.shot('07-gradient-editor', selector.gradient_editor.box)
    end
  end

  d.step('the remove button takes the stop away again') do
    app.background_selector.gradient_selector.then do |selector|
      selector.remove_button.signal_emit('clicked')
      d.check('two stops again') { selector.gradient_editor.stop_count == 2 }
      d.check('the gradient followed') do
        app.background_selector.gradient.gradient.steps.length == 2
      end
      d.check('and nothing is selected any more, so the step box is hidden') do
        !selector.button_revealer.reveal_child? && selector.gradient_editor.selected_button.nil?
      end
    end
  end

  d.step('picking a preset replaces the whole gradient') do
    app.background_selector.gradient_selector.then do |selector|
      AppConstants::PREDEFINED_GRADIENTS[3].then do |preset|
        selector.preset_button.flow_box.signal_emit(
          'child-activated',
          selector.preset_button.flow_box.get_child_at_index(3),
        )
        d.check('the stops came across') do
          selector.gradient_editor.stop_count == preset.steps.length
        end
        d.check('the angle came across') { selector.angle_selector.angle == preset.angle }
        d.check('the mode came across') { selector.type_group.active_name == preset.mode }
        d.check('the stored state followed') do
          Settings.new.gradient_state.include?(preset.steps.first.last)
        end
      end
    end
  end

  d.step('the preset popover renders') do
    app.background_selector.gradient_selector.preset_button.then do |button|
      d.check('six samples') { button.samples.length == GradientPresetButton::PRESET_COUNT }
      d.check('each is named') { button.samples.all? { |sample| !sample.tooltip_text.to_s.empty? } }
      button.menu_button.popup
    end
  end

  d.step('the popover is up') do
    d.shot('08-gradient-presets')
    app.background_selector.gradient_selector.preset_button.menu_button.popdown
  end

  step_dialog = nil
  d.step('the step dialog opens on the live gradient') do
    app.background_selector.gradient_selector.step_dialog_button.then do |button|
      button.button.signal_emit('clicked')
      step_dialog = button.dialog
    end
  end

  d.step('the step dialog lists one row per step') do
    d.check('a dialog is showing') { !app.window.visible_dialog.nil? }
    d.check('rows match the steps') do
      step_dialog.instance_variable_get(:@rows).length == step_dialog.gradient.steps.length
    end
    d.check('Add Step is available') { step_dialog.add_step_button.sensitive? }
    d.shot('09-step-dialog')
  end

  d.step('adding steps stops at five') do
    (GradientStepDialog::MAX_STEPS + 1).times { step_dialog.add_step_button.signal_emit('clicked') }
    d.check('five rows') { step_dialog.instance_variable_get(:@rows).length == GradientStepDialog::MAX_STEPS }
    d.check('and Add Step went insensitive') { !step_dialog.add_step_button.sensitive? }
    d.check('the gradient has five steps') { step_dialog.gradient.steps.length == GradientStepDialog::MAX_STEPS }
  end

  d.step('closing the dialog applies the edited gradient') do
    step_dialog.dialog.close
  end

  d.step('the selector took the edited gradient') do
    d.check('five stops on the bar') do
      app.background_selector.gradient_selector.gradient_editor.stop_count == 5
    end
    d.check('every pair is at least the minimum gap apart') do
      app.background_selector.gradient.gradient.steps.map(&:first).sort.each_cons(2).all? do |(a, b)|
        (b - a) >= (GradientStepDialog::MIN_GAP - 0.001)
      end
    end
  end

  d.step('switch to the image page') do
    app.background_selector.toggle_group.active_name = 'image'
  end

  d.step('the image page settles') do
    d.check('image is up') { app.background_selector.stack.visible_child_name == 'image' }
  end

  d.step('the image page renders') { d.shot('10-background-image') }

  d.step('the image selector previews the current picture') do
    app.background_selector.image_selector.then do |selector|
      d.check('a picture is loaded') { !app.background_selector.image.image.nil? }
      d.check('the preview has a paintable') { !selector.preview_picture.paintable.nil? }
      d.check('the preview is capped in width') do
        selector.preview_picture.paintable.intrinsic_width <= ImageSelector::PREVIEW_MAX_WIDTH
      end
      d.check('the file filter names the formats') do
        selector.image_filter.name == 'Supported Image Formats'
      end
      d.check('nine wallpaper presets') do
        selector.preset_button.presets.length == AppConstants::PRESET_IMAGES.length
      end
    end
  end

  d.step('picking a wallpaper preset loads it') do
    app.background_selector.image_selector.preset_button.then do |button|
      button.flow_box.signal_emit('child-activated', button.flow_box.get_child_at_index(2))
    end
  end

  d.step('the chosen wallpaper became the background') do
    d.check('the background points at the preset') do
      app.background_selector.image.file_path == AppConstants::PRESET_IMAGES[2]
    end
    d.check('and no load error') { app.background_selector.image.load_error.nil? }
  end

  aspect = AspectRatioSelector.new
  d.step('the aspect-ratio row opens on Auto') do
    scratch.child = Gtk::ListBox.new.tap do |list|
      list.add_css_class('boxed-list')
      list.append(aspect.build)
    end

    d.check('ten presets') { aspect.preset_buttons.length == AspectRatioSelector::PRESET_RATIOS.length }
    d.check('the label reads Auto') { aspect.value_label.text == 'Auto' }
    d.check('the ratio is empty') { aspect.ratio.empty? }
  end

  d.step('picking a preset and a custom ratio both report') do
    reported = []
    aspect.on_change { |ratio| reported << ratio }

    aspect.preset_buttons[2].first.signal_emit('clicked')
    d.check('16:9 took') { aspect.ratio == '16:9' }
    d.check('the label followed') { aspect.value_label.text == '16:9' }

    aspect.width_input.text = '7'
    aspect.height_input.text = '5'
    aspect.set_button.signal_emit('clicked')
    d.check('the custom ratio took') { aspect.ratio == '7:5' }
    d.check('both were reported') { reported == ['16:9', '7:5'] }

    aspect.width_input.text = '0'
    aspect.set_button.signal_emit('clicked')
    d.check('a zero side is refused') { aspect.ratio == '7:5' }

    aspect.ratio = '4:3'
    d.check('assigning a preset moves the label') { aspect.value_label.text == '4:3' }
  end

  d.step('the aspect-ratio row renders') { d.shot('11-aspect-ratio-row', scratch) }

  ratio_button = AspectRatioButton.new
  d.step('the crop ratio button reports the ratio it was given') do
    picked = []
    ratio_button.on_select { |ratio| picked << ratio }
    scratch.child = ratio_button.build

    d.check('six ratios') { ratio_button.ratio_buttons.length == AspectRatioButton::ASPECT_RATIOS.length }
    d.check('starts on the default icon') { ratio_button.icon.icon_name == AspectRatioButton::DEFAULT_ICON_NAME }

    ratio_button.ratio_buttons[5].first.signal_emit('clicked')
    d.check('16:9 reported') { (picked.first - (16.0 / 9.0)).abs < 0.001 }
    d.check('the icon followed') { ratio_button.icon.icon_name == 'aspect-ratio-16to9-symbolic' }
  end

  transparency = TransparencyBackground.new
  d.step('the transparency chequerboard sizes itself to the picture') do
    Gtk::Picture.new.tap do |picture|
      picture.pixbuf = GdkPixbuf::Pixbuf.new(file: File.join(AppConstants::IMAGES_DIR, 'graph.png'))
      transparency.picture = picture

      scratch.child = Gtk::Overlay.new.tap do |overlay|
        overlay.child = transparency.build
        overlay.add_overlay(picture)
      end
    end

    d.check('it knows its picture') { !transparency.picture.nil? }
    d.check('and the picture it was given has an image') do
      !transparency.picture.paintable.nil?
    end
  end

  # The board itself, not the opaque picture sitting on top of it.
  d.step('the chequerboard renders') { d.shot('12-transparency', transparency.drawing_area) }

  confirm = ConfirmCloseDialog.new(app.window)
  d.step('the close dialog asks before closing') do
    confirm.build
    answered = []
    confirm.show(on_confirm: -> { answered << :close }, on_copy: -> { answered << :copy })

    d.check('three responses') do
      %w[cancel copy close].all? { |response| confirm.dialog.has_response?(response) }
    end
    d.check("Don't Ask Again is off while the exit method is confirm") do
      !confirm.dont_ask_check_button.active?
    end
    @confirm_answered = answered
  end

  d.step('the close dialog renders') do
    d.shot('13-confirm-close')
    confirm.dialog.signal_emit('response', 'close')
    d.check('choosing Close ran the confirm handler') { @confirm_answered == [:close] }
  end

  d.step("ticking Don't Ask Again stores the exit method") do
    confirm.dont_ask_check_button.active = true
    d.check('stored as none') { Settings.new.exit_method == 'none' }

    confirm.dont_ask_check_button.active = false
    d.check('and back to confirm') { Settings.new.exit_method == 'confirm' }
    app.window.visible_dialog&.close
  end

  delete_dialog = DeleteScreenshotsDialog.new(app.window)
  d.step('deleting nothing is a notification, not a dialog') do
    notified = []
    delete_dialog.show([], on_delete: -> {}, on_notify: ->(message) { notified << message })

    d.check('nothing opened') { app.window.visible_dialog.nil? }
    d.check('and it said so') { notified == [DeleteScreenshotsDialog::EMPTY_MESSAGE] }
  end

  d.step('deleting screenshots lists them and asks') do
    Dir.glob(File.join(screenshot_folder, '*.png')).sort.map { |path| Gio::File.new_for_path(path).uri }
       .then do |uris|
      @delete_result = []
      delete_dialog.show(
        uris,
        on_delete: -> { @delete_result << :deleted },
        on_notify: ->(message) { @delete_result << message },
      )
    end
  end

  d.step('the delete dialog is up with the plural wording') do
    d.check('a dialog is showing') { !app.window.visible_dialog.nil? }
    d.check('plural heading') { app.window.visible_dialog.heading == DeleteScreenshotsDialog::PLURAL.first }
    d.shot('14-delete-screenshots')

    app.window.visible_dialog.tap do |sheet|
      sheet.signal_emit('response', 'delete')
      sheet.close
    end
    d.check('the delete handler ran') { @delete_result.first == :deleted }
    d.check('and reported the plural message') do
      @delete_result.last == DeleteScreenshotsDialog::DELETED_PLURAL
    end
  end

  d.step('the drop overlay wraps a page and starts hidden') do
    DropOverlay.new(title: 'Drop Image Here', child_widget: Gtk::Label.new('page')).then do |overlay|
      scratch.child = overlay.build
      d.check('title set') { overlay.title == 'Drop Image Here' }
      d.check('hidden to start') { !overlay.revealer.reveal_child? }

      overlay.drop_target = Gtk::DropTarget.new(Gio::File.gtype, :copy)
      d.check('target attached') { !overlay.drop_target.nil? }

      overlay.drop_target = nil
      d.check('target detached without raising') { overlay.drop_target.nil? }
    end
  end

  d.step('a shadowed image card loads its thumbnail') do
    ShadowedImageCard.new(File.join(AppConstants::IMAGES_DIR, 'graph.png')).then do |card|
      d.check('loaded') { card.loaded? }
      d.check('scaled down on load') { card.pixbuf.width <= ShadowedImageCard::FULL_SIZE.first }
      scratch.child = card.build
    end
  end

  d.step('the shadowed card renders') { d.shot('15-shadowed-card', scratch) }

  d.step('a card for a missing file reports instead of raising') do
    ShadowedImageCard.new('/nonexistent/x.png').then do |card|
      d.check('not loaded') { !card.loaded? }
      d.check('error recorded') { !card.load_error.nil? }
    end
  end

  font_dropdown = nil
  font_changes = []
  d.step('the font dropdown lists every family the font map knows') do
    font_dropdown = FontDropdown.new { |font| font_changes << font }
    scratch.child = font_dropdown.build

    d.check('it has fonts') { !font_dropdown.fonts.empty? }
    d.check('sorted') { font_dropdown.fonts == font_dropdown.fonts.sort }
    d.check('nothing selected yet') { font_dropdown.selected_font.nil? }
  end

  d.step('the font dropdown renders') { d.shot('17-font-dropdown', scratch) }

  d.step('picking a family reports it and setting one back moves the dropdown') do
    # The dropdown starts on index 0, so selecting index 0 again fires no
    # notify::selected — picking index 1 is what actually exercises the signal.
    font_dropdown.dropdown.selected = 1
    d.check('the second family was reported') { font_changes.last == font_dropdown.fonts[1] }
    d.check('selected_font followed') { font_dropdown.selected_font == font_dropdown.fonts[1] }

    font_dropdown.selected_font = font_dropdown.fonts.last
    d.check('assigning moves the dropdown') { font_dropdown.dropdown.selected == font_dropdown.fonts.length - 1 }
  end

  entry_popover = nil
  entry_changes = []
  entry_activated = []
  d.step('the text entry popover pops up pointing at the click') do
    entry_popover = TextEntryPopover.new(
      parent: scratch,
      font_size: 14,
      initial_text: 'hello',
      on_text_activate: ->(popover) { entry_activated << popover.text },
      on_text_changed: ->(buffer) { entry_changes << buffer.text },
      on_font_size_changed: ->(_button) {},
    )
    entry_popover.build
    entry_popover.popup_at_widget_coords(scratch, 10, 10)

    d.check('starts with the initial text') { entry_popover.text == 'hello' }
    d.check('the spin button holds the initial size') { entry_popover.spin.value == 14 }
  end

  d.step('the text entry popover renders') { d.shot('18-text-entry-popover', entry_popover.container) }

  d.step('typing reports the change, and Escape restores the original') do
    entry_popover.buffer.text = 'edited'
    d.check('the change was reported') { entry_changes.last == 'edited' }

    entry_popover.key_controller.signal_emit('key-pressed', Gdk::Keyval::KEY_Escape, 0, 0)
    d.check('the text was restored') { entry_popover.text == 'hello' }
  end

  d.step('Ctrl+Return activates with the current text') do
    entry_popover.buffer.text = 'confirmed'
    entry_popover.key_controller.signal_emit(
      'key-pressed',
      Gdk::Keyval::KEY_Return,
      0,
      Gdk::ModifierType::CONTROL_MASK,
    )
    d.check('the activate handler ran with that text') { entry_activated.last == 'confirmed' }
  end

  d.step('the window still renders after all of that') do
    scratch.close
    d.shot('16-window-final')
  end
end
