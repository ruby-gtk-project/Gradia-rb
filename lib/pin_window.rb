# frozen_string_literal: true

require 'adwaita'
require_relative 'logger'

# PinWindow is the floating, borderless window the "pin to screen" action
# opens: a fixed-size picture of the exported image with a header bar that
# only shows itself (via a fade animation) while the pointer hovers it.
#
# Ported from gradia/ui/pin_window.py. Adwaita::ApplicationWindow is broken in
# the Ruby bindings (see this app's other windows), so the root is a plain
# Gtk::ApplicationWindow, which still accepts the Adwaita header bar and
# toolbar view inside it.
class PinWindow
  FADE_IN_DURATION = 200
  FADE_OUT_DURATION = 350
  HOVER_OPACITY = 1.0
  IDLE_OPACITY = 0.25
  MAX_FRACTION = 0.5

  attr_reader :file_path

  def initialize(application, file_path: nil, logger: GradiaLogger.new)
    @application = application
    @file_path = file_path
    @logger = logger
  end

  def build
    window.tap do |win|
      win.resizable = false
      win.opacity = HOVER_OPACITY
      win.child = window_handle

      window_handle.tap do |handle|
        handle.child = toolbar_view

        toolbar_view.tap do |view|
          view.extend_content_to_top_edge = true
          view.add_top_bar(header_bar)
          view.content = picture

          picture.add_controller(hover_controller)
        end
      end

      load_image
    end
  end

  def window = @window ||= Gtk::ApplicationWindow.new(@application)

  def window_handle = @window_handle ||= Gtk::WindowHandle.new

  def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

  def header_bar
    @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
      bar.show_title = false
      bar.add_css_class('header-osd')
    end
  end

  def picture
    @picture ||= Gtk::Picture.new.tap do |pic|
      pic.can_shrink = true
      pic.keep_aspect_ratio = true
      pic.hexpand = true
      pic.vexpand = true
    end
  end

  def hover_controller
    @hover_controller ||= Gtk::EventControllerMotion.new.tap do |motion|
      motion.signal_connect('enter') { on_enter }
      motion.signal_connect('leave') { on_leave }
    end
  end

  def fade_in_animation
    @fade_in_animation ||= Adwaita::TimedAnimation.new(
      window,
      IDLE_OPACITY,
      HOVER_OPACITY,
      FADE_IN_DURATION,
      Adwaita::PropertyAnimationTarget.new(window, 'opacity'),
    ).tap { |animation| animation.easing = :ease_out_cubic }
  end

  def fade_out_animation
    @fade_out_animation ||= Adwaita::TimedAnimation.new(
      window,
      HOVER_OPACITY,
      IDLE_OPACITY,
      FADE_OUT_DURATION,
      Adwaita::PropertyAnimationTarget.new(window, 'opacity'),
    ).tap { |animation| animation.easing = :ease_in_cubic }
  end

  private

    # Upstream dims the window on hover (so the content behind a pinned
    # screenshot stays reachable) and restores it on leave; `fade_in` /
    # `fade_out` name the opacity direction each animation drives, not which
    # controller event plays them.
    def on_enter
      fade_in_animation.pause
      fade_out_animation.play
    end

    def on_leave
      fade_out_animation.pause
      fade_in_animation.play
    end

    def load_image
      if @file_path.nil?
        @logger.warning('PinWindow opened with no file path.')
      else
        GdkPixbuf::Pixbuf.new(file: @file_path).then { |pixbuf| apply_pixbuf(pixbuf) }
      end
    end

    def apply_pixbuf(pixbuf)
      scaled_size(pixbuf.width, pixbuf.height).then do |(width, height)|
        window.set_default_size(width, height)
        picture.pixbuf = pixbuf
      end
    end

    def scaled_size(image_width, image_height)
      monitor_geometry.then do |geometry|
        max_width = (geometry.width * MAX_FRACTION).to_i
        max_height = (geometry.height * MAX_FRACTION).to_i
        [max_width.to_f / image_width, max_height.to_f / image_height, 1.0].min.then do |scale|
          [(image_width * scale).to_i, (image_height * scale).to_i]
        end
      end
    end

    def monitor_geometry = Gdk::Display.default.monitors.get_item(0).geometry
end
