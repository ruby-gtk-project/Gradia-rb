# frozen_string_literal: true

require 'adwaita'

# DropOverlay wraps a page and fades a "drop it here" status page over it while
# a drag is hovering.
#
# Ported from gradia/overlay/drop_overlay.py. Upstream subclasses Adw.Bin and
# exposes title, child-widget and drop-target as GObject properties so the
# blueprint can set them; the port exposes them as plain accessors, which is
# what the Ruby callers assemble by hand anyway.
class DropOverlay
  ICON_NAME = 'document-send-symbolic'

  def initialize(title: nil, child_widget: nil)
    @title = title
    @child_widget = child_widget
  end

  def build
    bin.tap do |root|
      root.child = overlay

      overlay.tap do |stack|
        stack.add_overlay(revealer)
        stack.child = @child_widget
      end

      revealer.tap do |reveal|
        reveal.child = status
      end

      status.tap do |page|
        page.title = @title.to_s
      end
    end
  end

  def title = status.title

  def title=(value)
    @title = value
    status.title = value.to_s
  end

  def child_widget = overlay.child

  def child_widget=(widget)
    @child_widget = widget
    overlay.child = widget
  end

  def drop_target = @drop_target

  # Swapping the target moves the controller and the hover watch with it, so an
  # overlay can be re-targeted without leaking the old handler.
  def drop_target=(target)
    detach_drop_target
    attach_drop_target(target)
    @drop_target = target
  end

  def bin = @bin ||= Adwaita::Bin.new
  def overlay = @overlay ||= Gtk::Overlay.new

  def revealer
    @revealer ||= Gtk::Revealer.new.tap do |reveal|
      reveal.can_target = false
      reveal.transition_type = :crossfade
      reveal.reveal_child = false
    end
  end

  def status
    @status ||= Adwaita::StatusPage.new.tap do |page|
      page.icon_name = ICON_NAME
      page.add_css_class('drop-overlay-status-page')
    end
  end

  private

    def detach_drop_target
      if @drop_target
        bin.remove_controller(@drop_target)
        if @handler_id
          @drop_target.signal_handler_disconnect(@handler_id)
          @handler_id = nil
        end
      end
    end

    def attach_drop_target(target)
      if target
        @handler_id = target.signal_connect('notify::current-drop') do |controller, _param|
          revealer.reveal_child = !controller.current_drop.nil?
        end
        bin.add_controller(target)
      end
    end
end
