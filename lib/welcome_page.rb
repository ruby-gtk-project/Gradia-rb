# frozen_string_literal: true

require 'adwaita'
require_relative 'app_menu'
require_relative 'drop_overlay'
require_relative 'recent_picker'

# WelcomePage is what the window shows before an image is loaded: the recent
# screenshots, a Take a Screenshot and an Open Image button, and the whole page
# acting as a drop target.
#
# Ported from gradia/ui/welcome_page.py and data/ui/welcome_page.blp. Upstream
# reaches the window by calling get_root() and activating the `open-path` and
# `load-drop` actions on it; the port keeps the page ignorant of its window and
# takes the two handlers as callbacks, which is also what lets the page be
# built before the window it goes into.
#
# The narrow layout is driven by the breakpoint's apply and unapply signals
# rather than by Adw.Breakpoint setters: `adw_breakpoint_add_setter` wants a
# GValue, and the Ruby binding has no way to box one.
class WelcomePage
  COMPACT_CONDITION = 'max-width: 600sp'
  DROP_TITLE = 'Drop Image Here'
  TITLE = 'Enhance an Image'
  DESCRIPTION = 'Drag and drop one here'

  def initialize(app_menu: nil, on_open_path: nil, on_drop: nil)
    @app_menu = app_menu
    @on_open_path = on_open_path
    @on_drop = on_drop
  end

  def build
    breakpoint_bin.tap do |root|
      root.child = drop_overlay.build
      root.add_breakpoint(compact_breakpoint)

      compact_breakpoint.tap do |point|
        point.signal_connect('apply') { apply_compact(true) }
        point.signal_connect('unapply') { apply_compact(false) }
      end

      drop_overlay.tap do |overlay|
        overlay.drop_target = drop_target

        drop_target.tap do |target|
          target.signal_connect('drop') { |_target, value, _x, _y| on_file_dropped(value) }
        end
      end

      toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.content = status_page

        header_bar.tap do |bar|
          bar.pack_end(app_menu.button)
          bar.pack_end(source_snippets_button)
        end
      end

      status_page.tap do |page|
        page.child = main_box

        main_box.tap do |box|
          box.append(recent_picker.build)
          box.append(button_box)

          button_box.tap do |buttons|
            buttons.append(screenshot_button)
            buttons.append(open_image_button)
          end
        end
      end

      recent_picker.callback = ->(path, _gradient_index) { on_open_path(path) }
    end
  end

  def refresh_recent_picker = recent_picker.refresh

  def breakpoint_bin
    @breakpoint_bin ||= Adwaita::BreakpointBin.new.tap do |root|
      root.width_request = 360
      root.height_request = 150
    end
  end

  def compact_breakpoint
    @compact_breakpoint ||= Adwaita::Breakpoint.new(Adwaita::BreakpointCondition.parse(COMPACT_CONDITION))
  end

  def drop_overlay
    @drop_overlay ||= DropOverlay.new(title: DROP_TITLE, child_widget: toolbar_view)
  end

  def drop_target = @drop_target ||= Gtk::DropTarget.new(Gio::File.gtype, :copy).tap { |target| target.preload = true }

  def toolbar_view
    @toolbar_view ||= Adwaita::ToolbarView.new.tap do |view|
      view.top_bar_style = :flat
    end
  end

  def header_bar = @header_bar ||= Adwaita::HeaderBar.new

  def app_menu = @app_menu ||= AppMenu.new

  def source_snippets_button
    @source_snippets_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = 'code-symbolic'
      button.tooltip_text = 'Source Snippets'
      button.action_name = 'win.create-source-image'
    end
  end

  def status_page
    @status_page ||= Adwaita::StatusPage.new.tap do |page|
      page.title = TITLE
      page.description = DESCRIPTION
    end
  end

  def main_box
    @main_box ||= Gtk::Box.new(:vertical, 24).tap do |box|
      box.halign = :center
    end
  end

  def recent_picker = @recent_picker ||= RecentPicker.new

  def button_box
    @button_box ||= Gtk::Box.new(:horizontal, 12).tap do |box|
      box.margin_top = 10
      box.halign = :center
    end
  end

  def screenshot_button
    @screenshot_button ||= Gtk::Button.new.tap do |button|
      button.label = 'Take a Screenshot…'
      button.use_underline = true
      button.halign = :center
      button.action_name = 'win.screenshot'
      button.add_css_class('pill')
      button.add_css_class('text-button')
      button.add_css_class('suggested-action')
    end
  end

  def open_image_button
    @open_image_button ||= Gtk::Button.new.tap do |button|
      button.label = 'Open Image…'
      button.use_underline = true
      button.halign = :center
      button.action_name = 'win.open'
      button.add_css_class('pill')
      button.add_css_class('text-button')
    end
  end

  private

    def apply_compact(compact)
      recent_picker.compact = compact

      if compact
        button_box.orientation = :vertical
      else
        button_box.orientation = :horizontal
      end
    end

    def on_file_dropped(file)
      file.uri.then do |uri|
        if uri && @on_drop
          @on_drop.call(uri)
          true
        else
          false
        end
      end
    end

    def on_open_path(path)
      if @on_open_path
        @on_open_path.call(path)
      end
    end
end
