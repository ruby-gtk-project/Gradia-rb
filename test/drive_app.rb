# frozen_string_literal: true

# Drives the window the port opens: the primary menu, the two dialogs behind
# it, and the welcome-page widgets that are built but not yet placed on a page.
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

GtkDriver.drive(app, shots: 'tmp/shots') do |d, _app|
  d.window { app.window }

  d.step('the window opens with a header bar and a menu button') do
    d.check('window is visible') { app.window.visible? }
    d.check('title is set') { app.window.title == 'Gradia' }
    d.check('content is the toolbar view') { app.window.content == app.toolbar_view }
    d.check('status page carries the tagline') { app.status_page.description == AboutDialog::COMMENTS }
    d.check('menu button is in the window') { app.app_menu.button.root == app.window }
    d.check('menu has four items') { app.app_menu.section.n_items == 4 }
    d.check('stylesheet installed') { app.style.provider && app.style.css.include?('recent-button') }
    d.check('app icon resolves') { app.icon_theme.has_icon?(AppConstants::APP_ID) }
    d.check('ported action icon resolves') { app.icon_theme.has_icon?('one-circle-symbolic') }
    d.shot('01-window')
  end

  d.step('the window owns the actions the menu drives') do
    d.check('about') { app.window.lookup_action('about') }
    d.check('shortcuts') { app.window.lookup_action('shortcuts') }
    d.check('donate') { app.window.lookup_action('donate') }
    # GTK resolves <primary> to the platform modifier when it stores the
    # accelerator, so this reads back as <Control> on Linux.
    d.check('shortcuts has its accelerator') do
      app.app.get_accels_for_action('win.shortcuts') == ['<Control>question']
    end
  end

  d.step('win.about opens the About dialog') do
    app.window.lookup_action('about').activate(nil)
  end

  d.step('the About dialog is up and filled in') do
    d.check('a dialog is showing') { !app.window.visible_dialog.nil? }
    d.check('version is the gem version') { app.about_dialog.dialog.version == Gradia::Rb::VERSION }
    d.check('developer name') { app.about_dialog.dialog.developer_name == AboutDialog::DEVELOPER_NAME }
    d.check('website') { app.about_dialog.dialog.website == AppConstants::WEBSITE }
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

  toggle_group = ToggleGroup.new
  d.step('the background-mode toggle group picks one mode at a time') do
    app.toolbar_view.content = toggle_group.build

    d.check('nothing picked yet') { toggle_group.active_name.nil? }

    toggle_group.toggle_buttons.fetch('gradient').active = true
    d.check('clicking gradient selects it') { toggle_group.active_name == 'gradient' }

    toggle_group.toggle_buttons.fetch('solid').active = true
    d.check('clicking solid moves the selection') { toggle_group.active_name == 'solid' }
    d.check('gradient is no longer active') { !toggle_group.toggle_buttons.fetch('gradient').active? }

    toggle_group.toggle_buttons.fetch('solid').active = false
    d.check('the active toggle cannot be switched off') do
      toggle_group.active_name == 'solid' && toggle_group.toggle_buttons.fetch('solid').active?
    end

    changed = []
    toggle_group.on_change { |name| changed << name }
    toggle_group.active_name = 'image'
    d.check('setting it programmatically notifies') { changed == ['image'] }
  end

  d.step('the toggle group renders') { d.shot('04-toggle-group') }

  d.step('settings bind to the toggle group both ways') do
    Settings.new.then do |settings|
      settings.background_mode = 'gradient'
      ToggleGroup.new.tap(&:build).then do |bound|
        settings.bind_toggle_group(bound, 'background-mode')
        d.check('the stored mode seeds the group') { bound.active_name == 'gradient' }
        bound.toggle_buttons.fetch('image').active = true
        d.check('picking a mode writes it back') { Settings.new.background_mode == 'image' }
      end
    end
  end

  angle = AngleSelector.new(angle: 135)
  d.step('the angle selector snaps and reports') do
    app.toolbar_view.content = angle.build

    d.check('starts where it was told') { angle.angle == 135 }

    reported = []
    angle.on_angle_changed { |value| reported << value }

    angle.angle = 90
    d.check('setting the angle takes') { angle.angle == 90 }
    d.check('radians agree') { (angle.angle_radians - (Math::PI / 2)).abs < 0.001 }

    angle.angle_radians = Math::PI
    d.check('setting radians takes') { angle.angle == 180 }

    angle.click_gesture.signal_emit(
      'pressed',
      1,
      90.0,
      50.0,
    )
    d.check('a click moved the handle') { angle.angle != 180 }
    d.check('the click was reported') { reported.length == 1 }
  end

  d.step('the angle selector renders') { d.shot('05-angle-selector') }

  picker = RecentPicker.new
  d.step('the recent picker fills from a screenshot folder') do
    Settings.new.tap { |settings| settings.screenshot_folder = screenshot_folder }.then do |settings|
      picker.instance_variable_set(:@image_getter, RecentImageGetter.new(settings: settings))
    end
    app.toolbar_view.content = picker.build
    picker.refresh
  end

  d.step('three cards carry thumbnails and three are empty') do
    d.check('six cards in the grid') { picker.item_grid.children.length == 6 }
    d.check('the first three are sensitive') do
      (0..2).all? { |index| picker.item_grid.get_child_at_index(index).child.sensitive? }
    end
    d.check('the last three are not') do
      (3..5).all? { |index| !picker.item_grid.get_child_at_index(index).child.sensitive? }
    end
    d.check('tooltips name the files') do
      picker.item_grid.get_child_at_index(0).child.tooltip_text == 'shot0.png'
    end
    d.check('no error overlay') { !picker.error_overlay.visible? }
  end

  d.step('the filled picker renders') { d.shot('06-recent-picker') }

  d.step('clicking a card hands back its path and gradient') do
    picked = []
    picker.callback = ->(path, gradient_index) { picked << [path, gradient_index] }
    picker.item_grid.signal_emit('child-activated', picker.item_grid.get_child_at_index(0))
    d.check('the callback fired') { picked.length == 1 }
    d.check('with the newest path') { File.basename(picked.first.first) == 'shot0.png' }
    d.check('and a gradient index') { picked.first.last.zero? }
  end

  d.step('compact mode rebuilds the cards smaller') do
    picker.compact = true
    d.check('compact') { picker.compact? }
    d.check('cards are the compact size') do
      picker.item_grid.get_child_at_index(0).child.width_request == RecentPicker::COMPACT_IMAGE_SIZE.first
    end
  end

  # One extra tick: rebuilding the cards leaves the grid unrealised for a
  # frame, and a screenshot of an unrealised widget has no render node.
  d.step('the compact grid settles') { d.check('still six cards') { picker.item_grid.children.length == 6 } }

  d.step('the compact picker renders') { d.shot('07-recent-picker-compact') }

  empty_picker = RecentPicker.new(
    image_getter: RecentImageGetter.new(
      settings: Settings.new.tap { |settings| settings.screenshot_folder = '/nonexistent' },
    ),
  )

  d.step('an empty screenshot folder shows the error overlay') do
    app.toolbar_view.content = empty_picker.build
    d.check('overlay is visible') { empty_picker.error_overlay.visible? }
    d.check('grid is dimmed') { empty_picker.item_grid.opacity < 0.5 }
  end

  d.step('the error overlay renders') { d.shot('08-recent-picker-error') }

  drop_overlay = DropOverlay.new(title: 'Drop Image Here', child_widget: Gtk::Label.new('page'))

  d.step('the drop overlay wraps a page and starts hidden') do
    app.toolbar_view.content = drop_overlay.build
    d.check('title set') { drop_overlay.title == 'Drop Image Here' }
    d.check('child in place') { drop_overlay.child_widget.is_a?(Gtk::Label) }
    d.check('hidden to start') { !drop_overlay.revealer.reveal_child? }

    drop_overlay.drop_target = Gtk::DropTarget.new(Gio::File.gtype, :copy)
    d.check('target attached') { !drop_overlay.drop_target.nil? }

    drop_overlay.drop_target = nil
    d.check('target detached without raising') { drop_overlay.drop_target.nil? }
  end

  d.step('the drop overlay renders') { d.shot('09-drop-overlay') }

  card = ShadowedImageCard.new(File.join(AppConstants::IMAGES_DIR, 'graph.png'))

  d.step('a shadowed image card loads its thumbnail') do
    d.check('loaded') { card.loaded? }
    d.check('scaled down on load') { card.pixbuf.width <= ShadowedImageCard::FULL_SIZE.first }
    app.toolbar_view.content = card.build
  end

  d.step('the shadowed card renders') { d.shot('10-shadowed-card') }

  d.step('a card for a missing file reports instead of raising') do
    ShadowedImageCard.new('/nonexistent/x.png').then do |card|
      d.check('not loaded') { !card.loaded? }
      d.check('error recorded') { !card.load_error.nil? }
    end
  end
end
