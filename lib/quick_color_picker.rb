# frozen_string_literal: true

require 'adwaita'
require_relative 'color_conversions'

# QuickColorPicker is the row of colour swatches the drawing tools group
# shows for picking a stroke/fill colour, plus a "more colours" button that
# opens the system colour dialog. SimpleColorPicker is the compact
# icon/text button with the same swatches in a popover, used where a full
# row would not fit.
#
# Ported from gradia/ui/widget/quick_color_picker.py (ColorPickerMixin,
# QuickColorPicker and SimpleColorPicker). Upstream declares these as GObject
# subclasses with a `color` GObject::Property and a `color-changed` GSignal
# so the blueprint can wire them declaratively; the port builds them with
# plain Ruby and publishes the selection as a reader plus an `on_color_changed`
# callback, the same shape `ToggleGroup` and `PresetButton` use elsewhere in
# this port.
module ColorPickerMixin
  BASE_COLORS = [
    [[0.88, 0.11, 0.14, 1.0], 'Red'],
    [[0.18, 0.76, 0.49, 1.0], 'Green'],
    [[0.21, 0.52, 0.89, 1.0], 'Blue'],
    [[0.96, 0.83, 0.18, 1.0], 'Yellow'],
    [[0.0, 0.0, 0.0, 1.0], 'Black'],
    [[1.0, 1.0, 1.0, 1.0], 'White']
  ].freeze

  TRANSPARENT = [[0.0, 0.0, 0.0, 0.0], 'Transparent'].freeze

  # [Gdk::RGBA, name] pairs. `secondary` appends the Transparent swatch the
  # SimpleColorPicker popover shows but the QuickColorPicker row does not.
  def base_colors(secondary: false)
    palette = BASE_COLORS.map { |(r, g, b, a), name| [Gdk::RGBA.new(r, g, b, a), name] }
    palette << [Gdk::RGBA.new(*TRANSPARENT.first), TRANSPARENT.last] if secondary
    palette
  end

  def color_button(color, name)
    Gtk::Button.new.tap do |button|
      button.has_frame = false
      button.add_css_class('flat')
      button.add_css_class('color-hover-bg')
      button.tooltip_text = name
      button.child = color_box(color)
    end
  end

  def color_box(color)
    Gtk::Box.new(:horizontal, 0).tap do |box|
      box.add_css_class('color-button')
      box.set_size_request(24, 24)
      apply_color_css(box, color)
    end
  end

  def apply_color_css(widget, color)
    css = if color.alpha.zero?
            '.color-button { background-color: #b2b2b2; }'
          else
            components = Colors.components(color)
            r, g, b = [0, 1, 2].map { |i| ((components[i] * color.alpha) + (1.0 * (1.0 - color.alpha))) * 255 }
            ".color-button { background-color: rgb(#{r.to_i}, #{g.to_i}, #{b.to_i}); }"
          end

    Gtk::CssProvider.new.tap do |provider|
      provider.load_from_string(css)
      widget.style_context.add_provider(provider, Gtk::StyleProvider::PRIORITY_APPLICATION)
    end
  end

  def more_colors_button
    Gtk::Button.new.tap do |button|
      button.has_frame = false
      button.add_css_class('flat')
      button.add_css_class('color-hover-bg')
      button.tooltip_text = 'More Colors'
      button.child = Gtk::Image.new.tap do |image|
        image.icon_name = 'color-symbolic'
        image.icon_size = :normal
      end
    end
  end

  # Opens the system colour dialog and calls `block` with the chosen
  # Gdk::RGBA, or not at all if the person cancels.
  def show_color_dialog(current_color, with_alpha, &block)
    dialog = Gtk::ColorDialog.new
    dialog.title = 'Choose Color'
    dialog.with_alpha = with_alpha

    dialog.choose_rgba(nil, current_color) do |_source, result|
      block.call(dialog.choose_rgba_finish(result))
    rescue StandardError
      nil
    end
  end
end

# The horizontal row of colour swatches with a checkmark on the selected
# one, used inline in the drawing tools group.
class QuickColorPicker
  include ColorPickerMixin

  def initialize(color: Gdk::RGBA.new(0.2, 0.4, 1.0, 1.0), with_alpha: true)
    @color = color
    @with_alpha = with_alpha
    @buttons = []
  end

  attr_reader :color

  def with_alpha=(value)
    @with_alpha = value
  end

  def on_color_changed(&block)
    @on_color_changed = block
  end

  def build
    row.tap { rebuild_row }
  end

  def color=(new_color)
    @color = new_color
    update_selection
  end

  # Replaces the swatch palette (e.g. with recently-used colours) and
  # redraws the row in place.
  def color_list=(colors)
    @custom_colors = colors
    rebuild_row
  end

  private

    def row
      @row ||= Gtk::Box.new(:horizontal, 4).tap do |box|
        box.halign = :center
      end
    end

    def palette
      @custom_colors || base_colors
    end

    def rebuild_row
      row.tap do |box|
        box.remove(box.first_child) while box.first_child
        @buttons = []

        palette.each do |swatch_color, name|
          checkmark = Gtk::Image.new.tap do |image|
            image.icon_name = 'object-select-symbolic'
            image.pixel_size = 12
            image.add_css_class('checkmark-icon')
            image.add_css_class('dark') if Colors.light_color_rgba?(swatch_color)
          end

          overlay = Gtk::Overlay.new.tap do |ov|
            ov.set_size_request(20, 20)
            ov.child = color_box(swatch_color)
            ov.add_overlay(checkmark)
            ov.halign = :center
            ov.valign = :center
          end

          button = Gtk::Button.new.tap do |btn|
            btn.has_frame = false
            btn.add_css_class('flat')
            btn.add_css_class('color-hover-bg')
            btn.tooltip_text = name
            btn.child = overlay
          end

          button.signal_connect('clicked') { select(swatch_color, button, checkmark) }
          box.append(button)
          @buttons << [button, swatch_color, checkmark]
        end

        box.append(more_button)
      end
      update_selection
    end

    def more_button
      @more_button ||= more_colors_button.tap do |button|
        button.signal_connect('clicked') do
          show_color_dialog(@color, @with_alpha) { |picked| select(picked, nil, nil) }
        end
      end
    end

    def select(new_color, _button, _checkmark)
      @color = new_color
      update_selection
      @on_color_changed&.call(new_color)
    end

    def update_selection
      @buttons.each do |button, swatch_color, checkmark|
        matches = colors_match?(swatch_color, @color)
        checkmark.remove_css_class('visible') unless matches
        checkmark.add_css_class('visible') if matches
      end
    end

    def colors_match?(a, b)
      tolerance = 0.01
      ac = Colors.components(a)
      bc = Colors.components(b)
      (0..3).all? { |i| (ac[i] - bc[i]).abs < tolerance }
    end
end

# The compact button form: an icon and/or label that opens a popover of the
# same swatches. Used where a full QuickColorPicker row would not fit.
class SimpleColorPicker
  include ColorPickerMixin

  def initialize(color: Gdk::RGBA.new(0.2, 0.4, 1.0, 1.0), icon_name: nil, text: nil, with_alpha: true)
    @color = color
    @icon_name = icon_name
    @text = text
    @with_alpha = with_alpha
  end

  attr_reader :color, :icon_name, :text

  def on_color_changed(&block)
    @on_color_changed = block
  end

  def build
    button.tap do
      update_content
      update_color_style
    end
  end

  def color=(new_color)
    @color = new_color
    update_color_style
  end

  def icon_name=(name)
    @icon_name = name
    update_content
  end

  def text=(value)
    @text = value
    update_content
  end

  def color_list=(colors)
    @custom_colors = colors
    rebuild_popover
  end

  private

    def button
      @button ||= Gtk::Button.new.tap do |btn|
        btn.has_frame = false
        btn.add_css_class('flat')
        btn.child = content_box
        btn.signal_connect('clicked') { popover.popup }
      end
    end

    def content_box
      @content_box ||= Gtk::Box.new(:horizontal, 6).tap do |box|
        box.halign = :center
        box.valign = :center
        box.append(icon)
        box.append(label)
      end
    end

    def icon
      @icon ||= Gtk::Image.new.tap { |image| image.visible = false }
    end

    def label
      @label ||= Gtk::Label.new.tap { |lab| lab.visible = false }
    end

    def popover
      @popover ||= Gtk::Popover.new.tap do |pop|
        pop.set_parent(button)
        pop.position = :bottom
        rebuild_popover
      end
    end

    def rebuild_popover
      popover_box = Gtk::Box.new(:horizontal, 6)

      (@custom_colors || base_colors(secondary: true)).each do |swatch_color, name|
        swatch = color_button(swatch_color, name)
        swatch.signal_connect('clicked') do
          popover.popdown
          self.color = swatch_color
          @on_color_changed&.call(swatch_color)
        end
        popover_box.append(swatch)
      end

      popover_box.append(
        more_colors_button.tap do |more|
          more.signal_connect('clicked') do
            popover.popdown
            show_color_dialog(@color, @with_alpha) do |picked|
              self.color = picked
              @on_color_changed&.call(picked)
            end
          end
        end
      )

      popover.child = popover_box
    end

    def update_content
      if @icon_name
        icon.icon_name = @icon_name
        icon.visible = true
      else
        icon.visible = false
      end

      if @text
        label.text = @text
        label.visible = true
      else
        label.visible = false
      end

      content_box.set_size_request(24, 24) if !@icon_name && !@text
    end

    def update_color_style
      css = if @color.alpha.zero?
              'button { background-color: #b2b2b2; }'
            else
              r, g, b = Colors.components(@color).first(3).map { |c| (c * 255).to_i }
              "button { background-color: rgba(#{r}, #{g}, #{b}, #{@color.alpha}); }"
            end

      Gtk::CssProvider.new.tap do |provider|
        provider.load_from_string(css)
        button.style_context.add_provider(provider, Gtk::StyleProvider::PRIORITY_APPLICATION)
      end

      dark = Colors.light_color_rgba?(@color)
      [icon, label].each do |widget|
        widget.remove_css_class('dark') unless dark
        widget.add_css_class('dark') if dark
      end
    end
end
