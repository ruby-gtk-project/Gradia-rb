# frozen_string_literal: true

require 'gtk4'

# TextEntryPopover is the popover the drawing overlay opens for its text
# tool: a scrollable Gtk::TextView plus a font-size spin button, linked into
# one pill, that pops up pointing at the spot on the canvas the user clicked.
#
# Ported from gradia/overlay/text_entry_popover.py. Upstream builds the
# popover from a blueprint template (text_entry_popover.ui); this port builds
# the same widget tree declaratively instead, as the rest of this codebase
# does, and keeps Ctrl+Return to confirm and Escape to restore the original
# text and font size.
class TextEntryPopover
  def initialize(parent:, font_size: 14, initial_text: '', on_text_activate:, on_text_changed:, on_font_size_changed:)
    @parent = parent
    @original_text = initial_text
    @original_font_size = font_size
    @on_text_activate = on_text_activate
    @on_text_changed = on_text_changed
    @on_font_size_changed = on_font_size_changed
  end

  def build
    popover.tap do |pop|
      pop.set_parent(@parent)
      pop.child = container

      container.tap do |box|
        box.add_css_class('linked')
        box.append(scrolled)
        box.append(spin)

        scrolled.tap do |scroll|
          scroll.child = text_view

          text_view.tap do |view|
            view.add_css_class('rounded-top')
            view.add_controller(key_controller)

            buffer.tap do |buf|
              buf.signal_connect('changed') { |b| @on_text_changed.call(b) }

              unless @original_text.to_s.empty?
                buf.text = @original_text
                buf.select_range(buf.start_iter, buf.end_iter)
              end
            end
          end
        end

        spin.tap do |s|
          size_adjustment.value = @original_font_size
          s.signal_connect('value-changed') { |button| @on_font_size_changed.call(button) }
        end
      end
    end
  end

  def text
    buffer.text
  end

  def update_original_values(text, font_size)
    @original_text = text
    @original_font_size = font_size
  end

  def popup_at_widget_coords(widget, x, y)
    allocation = widget.allocation
    popover.pointing_to = Gdk::Rectangle.new(
      allocation.x + x.to_i,
      allocation.y + y.to_i,
      1,
      1,
    )
    popover.popup
    text_view.grab_focus
  end

  def popover = @popover ||= Gtk::Popover.new

  def container = @container ||= Gtk::Box.new(:horizontal, 0)

  def scrolled
    @scrolled ||= Gtk::ScrolledWindow.new.tap do |scroll|
      scroll.set_size_request(200, 80)
    end
  end

  def text_view = @text_view ||= Gtk::TextView.new

  def buffer = @buffer ||= text_view.buffer

  def size_adjustment
    @size_adjustment ||= Gtk::Adjustment.new(
      14.0,
      6.0,
      128.0,
      1.0,
      4.0,
      0.0,
    )
  end

  def spin = @spin ||= Gtk::SpinButton.new(size_adjustment, 1.0, 0)

  def key_controller
    @key_controller ||= Gtk::EventControllerKey.new.tap do |controller|
      controller.signal_connect('key-pressed') { |_c, keyval, _keycode, state| on_key_pressed(keyval, state) }
    end
  end

  private

    def on_key_pressed(keyval, state)
      if [Gdk::Keyval::KEY_Return, Gdk::Keyval::KEY_KP_Enter].include?(keyval) && state.control_mask?
        @on_text_activate.call(self)
        true
      elsif keyval == Gdk::Keyval::KEY_Escape
        restore_original_values
        popover.popdown
        true
      else
        false
      end
    end

    def restore_original_values
      buffer.text = @original_text
      size_adjustment.value = @original_font_size
    end
end
