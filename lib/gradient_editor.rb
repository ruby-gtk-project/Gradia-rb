# frozen_string_literal: true

require 'adwaita'
require_relative 'colors'

# GradientColorButton is one stop on the gradient bar: a round swatch filled
# with the stop's colour, carrying a pencil icon, which is dragged along the
# bar to move the stop and clicked to recolour it.
#
# Ported from gradia/ui/widget/gradient_editor.py (the GradientColorButton
# class). Upstream declares colour, step and selected as GObject properties and
# reacts to its own notify signals; a Ruby class cannot register properties on
# a boxed Gtk type, so they are plain accessors here and the editor is told
# about a change directly.
class GradientColorButton
  ICON_NAME = 'edit-symbolic'
  ICON_PIXEL_SIZE = 18
  ICON_WIDTH = 30

  attr_reader :step, :color

  def initialize(step: 0.0, color: '#000000', &on_color_change)
    @step = step.clamp(0.0, 1.0)
    @on_color_change = on_color_change
    @selected = false
    @color = as_rgba(color)
  end

  def build
    box.tap do |root|
      root.append(icon_box)

      icon_box.tap { |inner| inner.append(icon) }
    end
  end

  def on_color_change(&block)
    @on_color_change = block
  end

  def step=(value)
    @step = value.clamp(0.0, 1.0)
    box.tooltip_text = format('%d%%', (GradientEditor.scale_correction(@step) * 100).round)
  end

  def color=(value)
    @color = as_rgba(value)
    update_color_css
    notify_color_change
  end

  def color_string = @color.to_s

  def selected? = @selected

  def selected=(value)
    @selected = value
    if value
      box.add_css_class('selected')
    else
      box.remove_css_class('selected')
    end
  end

  # Upstream's drag handler clicks through to the colour picker when the
  # pointer never moved, so the editor needs to know whether this drag was a
  # move or a click.
  attr_accessor :moved

  def box
    @box ||= Gtk::Box.new(:horizontal, 0).tap do |root|
      root.add_css_class('gradient-color-picker')
      root.add_css_class('gradient-editor-button')
      root.tooltip_text = format('%d%%', (GradientEditor.scale_correction(@step) * 100).round)
    end
  end

  def icon_box
    @icon_box ||= Gtk::Box.new(:horizontal, 0).tap do |inner|
      inner.halign = :center
      inner.valign = :center
    end
  end

  def icon
    @icon ||= Gtk::Image.new.tap do |image|
      image.icon_name = ICON_NAME
      image.pixel_size = ICON_PIXEL_SIZE
      image.set_size_request(ICON_WIDTH, -1)
      image.add_css_class('gradient-color-button')
    end
  end

  # The swatch's fill is a generated rule rather than an inline style, which
  # is the only way to colour a Gtk::Box.
  def color_provider
    @color_provider ||= Gtk::CssProvider.new.tap do |provider|
      box.style_context.add_provider(provider, Gtk::StyleProvider::PRIORITY_APPLICATION + 2)
    end
  end

  # Picking a new colour goes through the system colour chooser, without the
  # alpha channel: a gradient stop upstream is an opaque "rgb(r,g,b)" string.
  def open_color_picker(parent, &after)
    color_dialog.choose_rgba(parent, @color, nil) do |dialog, result, _data|
      chosen_color(dialog, result).then do |rgba|
        if rgba
          self.color = rgba
          if after
            after.call
          end
        end
      end
    end
  end

  def color_dialog
    @color_dialog ||= Gtk::ColorDialog.new.tap do |dialog|
      dialog.with_alpha = false
    end
  end

  def update_color_css
    color_provider.load_from_string(
      ".gradient-color-picker { background-color: #{@color}; border-radius: 9999px; }",
    )

    if Colors.light_color_rgba?(@color)
      icon.add_css_class('dark')
    else
      icon.remove_css_class('dark')
    end
  end

  private

    # A cancelled chooser raises, which is the only way the binding reports
    # "the user closed it".
    def chosen_color(dialog, result)
      dialog.choose_rgba_finish(result)
    rescue StandardError
      nil
    end

    def as_rgba(value)
      case value
      when Gdk::RGBA then value
      else Gdk::RGBA.parse(value.to_s)
      end
    end

    def notify_color_change
      if @on_color_change
        @on_color_change.call(self)
      end
    end
end

# GradientEditor is the gradient bar under the angle dial: a live preview of
# the gradient with a draggable stop button sitting on each colour step.
#
# Ported from gradia/ui/widget/gradient_editor.py (the GradientEditor class).
# Two deviations, both forced by the bindings:
#
#   * upstream finds the pointer through the display's default seat on every
#     drag update, because it moves the button under the cursor rather than by
#     the drag offset; Gtk::GestureDrag already reports that offset, so the
#     port tracks the button's position at drag-begin and adds the offset to
#     it, which lands in the same place without touching the seat API;
#   * the stop buttons are plain Ruby objects, so the editor keeps the list of
#     them and does the deselect-the-others bookkeeping that upstream puts in
#     each button's own notify handler.
class GradientEditor
  WIDTH = 248
  HEIGHT = 34
  BUTTON_WIDTH = 34
  MAX_STOPS = 5
  MIN_NEW_STOP_DISTANCE = 0.13

  # Upstream squeezes the stored 0–1 step range into the 7%–93% band the bar
  # can actually show, because a button centred on 0 or 1 would hang half off
  # the end. Everything the editor hands out is corrected back.
  SCALE_LOW = 0.07
  SCALE_HIGH = 0.93

  def self.scale_correction(value) = (value - SCALE_LOW) / (SCALE_HIGH - SCALE_LOW)

  def self.reverse_scale_correction(value) = (value * (SCALE_HIGH - SCALE_LOW)) + SCALE_LOW

  def initialize(&on_gradient_change)
    @on_gradient_change = on_gradient_change
    @buttons = []
    @drag_offset = nil
    @on_selection_change = nil
  end

  def build
    box.tap do |root|
      root.append(overlay)

      overlay.tap do |stack|
        stack.child = gradient_background
        stack.add_overlay(button_container)

        button_container.tap do |container|
          container.add_controller(click_gesture)

          click_gesture.tap do |gesture|
            gesture.signal_connect('pressed') { |_g, n_press, x, _y| on_background_clicked(n_press, x) }
          end
        end
      end
    end
  end

  def on_gradient_change(&block)
    @on_gradient_change = block
  end

  # The selector shows the selected stop's position and a remove button, so it
  # needs to hear when the selection changes.
  def on_selection_change(&block)
    @on_selection_change = block
  end

  def selected_button = @buttons.find(&:selected?)

  def stop_count = @buttons.length

  # [[position, "rgb(r,g,b)"], …] sorted by position, in the 0–1 range the
  # Gradient model stores.
  def gradient_data
    @buttons.sort_by(&:step).map do |button|
      [self.class.scale_correction(button.step), Colors.rgb_string(button.color)]
    end
  end

  def gradient_data=(data)
    @buttons.each { |button| button_container.remove(button.box) }
    @buttons = []
    data.each { |(step, color)| add_button(new_button(self.class.reverse_scale_correction(step), color)) }
    update_button_positions
    update_gradient_css
    notify_selection_change
  end

  def remove_selected_button
    selected_button.then do |button|
      if button
        remove_button(button)
      end
    end
  end

  def box
    @box ||= Gtk::Box.new(:horizontal, 0).tap do |root|
      root.hexpand = false
      root.halign = :center
      root.set_size_request(WIDTH, HEIGHT)
      root.add_css_class('gradient-editor')
    end
  end

  def overlay = @overlay ||= Gtk::Overlay.new

  def gradient_background
    @gradient_background ||= Gtk::Box.new(:horizontal, 0).tap do |bar|
      bar.hexpand = false
      bar.set_size_request(WIDTH, HEIGHT)
      bar.add_css_class('gradient-background')
    end
  end

  def button_container
    @button_container ||= Gtk::Fixed.new.tap do |container|
      container.overflow = :visible
      container.hexpand = false
      container.set_size_request(WIDTH, HEIGHT + 2)
    end
  end

  def click_gesture = @click_gesture ||= Gtk::GestureClick.new

  def gradient_provider
    @gradient_provider ||= Gtk::CssProvider.new.tap do |provider|
      gradient_background.style_context.add_provider(provider, Gtk::StyleProvider::PRIORITY_APPLICATION + 1)
    end
  end

  private

    def new_button(step, color)
      GradientColorButton.new(step: step, color: color) { update_gradient_css }
    end

    def add_button(button)
      @buttons.push(button)
      button_container.put(button.build, 0, -2)
      button.update_color_css
      attach_drag(button)
      notify_gradient_change
    end

    def attach_drag(button)
      Gtk::GestureDrag.new.tap do |gesture|
        gesture.touch_only = false
        gesture.signal_connect('drag-begin') { on_drag_begin(button) }
        gesture.signal_connect('drag-update') { |_g, offset_x, offset_y| on_drag_update(button, offset_x, offset_y) }
        gesture.signal_connect('drag-end') { on_drag_end(button) }
        button.box.add_controller(gesture)
      end
    end

    def remove_button(button)
      if @buttons.length > 2
        @buttons.delete(button)
        button_container.remove(button.box)
        update_gradient_css
        notify_selection_change
        notify_gradient_change
      end
    end

    def select(button)
      @buttons.each { |other| other.selected = other.equal?(button) }
      notify_selection_change
    end

    def on_drag_begin(button)
      button.moved = false
      select(button)
      @drag_offset = button_container.get_child_position(button.box).first
    end

    # The clamped position is converted back into a step before the move, so
    # the button and the gradient stop can never drift apart.
    def on_drag_update(button, offset_x, offset_y)
      if @drag_offset
        if Math.hypot(offset_x, offset_y) > 1
          button.moved = true
        end

        step_for(@drag_offset + offset_x).then do |step|
          unless overlaps?(button, step)
            button.step = step
            move_to_step(button, step)
            update_gradient_css
          end
        end
      end
    end

    def on_drag_end(button)
      if button.moved
        notify_gradient_change
      else
        button.open_color_picker(box.root) { notify_gradient_change }
      end

      @drag_offset = nil
      update_gradient_css
    end

    def step_for(x)
      (x.clamp(0, WIDTH - BUTTON_WIDTH) + (BUTTON_WIDTH / 2.0)).then do |center|
        (center / WIDTH).clamp(0.0, 1.0)
      end
    end

    def move_to_step(button, step)
      ((step * WIDTH) - (BUTTON_WIDTH / 2.0)).clamp(0, WIDTH - BUTTON_WIDTH).then do |x|
        button_container.move(button.box, x.to_i, 0)
      end
    end

    # Two stops may not sit on top of each other, so a drag that would put one
    # inside another's box is simply not applied.
    def overlaps?(moving_button, step)
      ((step * WIDTH) - (BUTTON_WIDTH / 2.0)).then do |left|
        @buttons.reject { |other| other.equal?(moving_button) }.any? do |other|
          ((other.step * WIDTH) - (BUTTON_WIDTH / 2.0)).then do |other_left|
            !((left + BUTTON_WIDTH) <= other_left || (other_left + BUTTON_WIDTH) <= left)
          end
        end
      end
    end

    # Clicking the bar between two stops adds one there, interpolated from its
    # neighbours — up to five stops, and never within 13% of an existing one.
    def on_background_clicked(n_press, x)
      if n_press == 1 && @buttons.length < MAX_STOPS
        (x / WIDTH).clamp(0.0, 1.0).then do |step|
          unless near_existing?(step)
            create_button_at(step, interpolated_color(step))
          end
        end
      end
    end

    def near_existing?(step)
      @buttons.any? { |button| (button.step - step).abs < MIN_NEW_STOP_DISTANCE }
    end

    def create_button_at(step, color)
      new_button(step, color).tap do |button|
        add_button(button)
        select(button)
        update_button_positions
        update_gradient_css
      end
    end

    def interpolated_color(step)
      @buttons.sort_by(&:step).then do |sorted|
        if step <= sorted.first.step
          sorted.first.color
        elsif step >= sorted.last.step
          sorted.last.color
        else
          blend(sorted, step)
        end
      end
    end

    def blend(sorted, step)
      sorted.each_cons(2) do |(left, right)|
        if left.step <= step && step <= right.step
          break mix(left.color, right.color, fraction(left.step, right.step, step))
        end
      end
    end

    def fraction(left_step, right_step, step)
      (right_step - left_step).then do |span|
        if span.zero?
          0.0
        else
          (step - left_step) / span
        end
      end
    end

    def mix(left, right, t)
      Gdk::RGBA.new(
        left.red + (t * (right.red - left.red)),
        left.green + (t * (right.green - left.green)),
        left.blue + (t * (right.blue - left.blue)),
        left.alpha + (t * (right.alpha - left.alpha)),
      )
    end

    def update_button_positions
      @buttons.each { |button| move_to_step(button, button.step) }
      button_container.queue_draw
    end

    def update_gradient_css
      unless @buttons.empty?
        gradient_provider.load_from_string(".gradient-background { background: #{background_value}; }")
      end
    end

    def background_value
      @buttons.sort_by(&:step).then do |sorted|
        if sorted.length == 1
          sorted.first.color_string
        else
          "linear-gradient(to right, #{sorted.map { |b| "#{b.color_string} #{b.step * 100}%" }.join(', ')})"
        end
      end
    end

    def notify_gradient_change
      if @on_gradient_change
        @on_gradient_change.call(gradient_data)
      end
    end

    def notify_selection_change
      if @on_selection_change
        @on_selection_change.call(selected_button)
      end
    end
end
