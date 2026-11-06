# frozen_string_literal: true

require 'adwaita'
require_relative 'color_conversions'
require_relative 'solid_background'

# ColorPresetButton is one swatch in the solid-colour grid: a 40×40 square
# filled with its colour, with a checkmark that appears when it is the chosen
# one.
#
# Ported from gradia/graphics/solid.py (the ColorPresetButton class).
class ColorPresetButton
  SIZE = 40
  CHECKMARK_PIXEL_SIZE = 16

  attr_reader :color, :alpha

  def initialize(color:, alpha: 1.0, tooltip_text: '', &on_click)
    @color = color
    @alpha = alpha
    @tooltip_text = tooltip_text
    @on_click = on_click
  end

  def build
    button.tap do |swatch|
      swatch.child = overlay

      overlay.tap do |stack|
        stack.child = Gtk::Box.new(:horizontal, 0)
        stack.add_overlay(checkmark)
      end

      swatch.signal_connect('clicked') { notify_click }
    end
  end

  def selected=(value)
    if value
      checkmark.add_css_class('visible')
    else
      checkmark.remove_css_class('visible')
    end
  end

  def button
    @button ||= Gtk::Button.new.tap do |swatch|
      swatch.valign = :center
      swatch.set_size_request(SIZE, SIZE)
      swatch.margin_top = 6
      swatch.margin_bottom = 6
      swatch.margin_start = 6
      swatch.margin_end = 6
      swatch.tooltip_text = @tooltip_text
      swatch.focusable = true
      swatch.can_focus = true
      swatch.add_css_class('color-button')
      apply_fill(swatch)
    end
  end

  def overlay
    @overlay ||= Gtk::Overlay.new.tap do |stack|
      stack.set_size_request(CHECKMARK_PIXEL_SIZE, CHECKMARK_PIXEL_SIZE)
      stack.halign = :center
      stack.valign = :center
    end
  end

  def checkmark
    @checkmark ||= Gtk::Image.new.tap do |mark|
      mark.icon_name = 'object-select-symbolic'
      mark.pixel_size = CHECKMARK_PIXEL_SIZE
      mark.add_css_class('checkmark-icon')

      if Colors.light_color_hex?(@color) || @alpha.zero?
        mark.add_css_class('dark')
      end
    end
  end

  private

    # A fully transparent swatch gets the stylesheet's chequerboard class
    # instead of a generated fill, which is how upstream shows "no colour".
    def apply_fill(swatch)
      if @alpha.zero?
        swatch.add_css_class('transparent-color-button')
      else
        Gtk::CssProvider.new.tap do |provider|
          provider.load_from_string("button { background-color: #{Colors.hex_to_rgba(@color, @alpha)}; }")
          swatch.style_context.add_provider(provider, Gtk::StyleProvider::PRIORITY_APPLICATION)
        end
      end
    end

    def notify_click
      if @on_click
        @on_click.call(@color, @alpha)
      end
    end
end

# ColorPickerButton is the last cell of the grid: the "More Colors" button that
# opens the system colour chooser.
#
# Ported from gradia/graphics/solid.py (the ColorPickerButton class).
class ColorPickerButton
  SIZE = 30
  OVERLAY_SIZE = 40
  CHECKMARK_PIXEL_SIZE = 16

  def initialize(&on_pick)
    @on_pick = on_pick
  end

  def build
    button.tap do |picker|
      picker.child = overlay

      overlay.tap { |stack| stack.add_overlay(checkmark) }

      picker.signal_connect('clicked') { open_color_picker }
    end
  end

  def selected=(value)
    if value
      checkmark.add_css_class('visible')
    else
      checkmark.remove_css_class('visible')
    end
  end

  def button
    @button ||= Gtk::Button.new.tap do |picker|
      picker.valign = :center
      picker.set_size_request(SIZE, SIZE)
      picker.margin_top = 6
      picker.margin_bottom = 6
      picker.margin_start = 6
      picker.margin_end = 6
      picker.tooltip_text = 'More Colors'
      picker.focusable = true
      picker.can_focus = true
      picker.add_css_class('color-button')
      picker.add_css_class('color-picker-button')
    end
  end

  def overlay
    @overlay ||= Gtk::Overlay.new.tap do |stack|
      stack.set_size_request(OVERLAY_SIZE, OVERLAY_SIZE)
      stack.halign = :center
      stack.valign = :center
    end
  end

  def checkmark
    @checkmark ||= Gtk::Image.new.tap do |mark|
      mark.icon_name = 'object-select-symbolic'
      mark.pixel_size = CHECKMARK_PIXEL_SIZE
      mark.add_css_class('checkmark-icon')
    end
  end

  def color_dialog = @color_dialog ||= Gtk::ColorDialog.new

  private

    def open_color_picker
      color_dialog.choose_rgba(
        button.root,
        Gdk::RGBA.new(
          0.5,
          0.5,
          0.5,
          1.0,
        ),
        nil,
      ) do |dialog, result, _data|
        chosen_color(dialog, result).then do |rgba|
          if rgba && @on_pick
            @on_pick.call(Colors.rgba_to_hex(rgba)[0, 7], rgba.alpha)
          end
        end
      end
    end

    def chosen_color(dialog, result)
      dialog.choose_rgba_finish(result)
    rescue StandardError
      nil
    end
end

# SolidSelector is the solid-colour page of the background sidebar: fourteen
# named swatches in a five-column grid, plus the colour chooser.
#
# Ported from gradia/graphics/solid.py (the SolidSelector class) and
# data/ui/selectors/solid_selector.blp.
class SolidSelector
  COLUMNS = 5

  # Upstream spells these "#aarrggbb" — alpha first — and splits the alpha off
  # when it builds each swatch; the port keeps the same table so the two read
  # the same, and splits it the same way.
  COMMON_COLORS = [
    ['#fff66151', 'Red'],
    ['#ffe66100', 'Orange'],
    ['#fff6d32d', 'Yellow'],
    ['#ff33d17a', 'Green'],
    ['#ff3584e4', 'Blue'],
    ['#ffc061cb', 'Purple'],
    ['#ffffd1dc', 'Pastel Pink'],
    ['#fffff4d1', 'Pastel Yellow'],
    ['#ffd1ffd1', 'Pastel Green'],
    ['#ffd1f0ff', 'Pastel Cyan'],
    ['#ffffffff', 'White'],
    ['#ff000000', 'Black'],
    ['#ff77767b', 'Gray'],
    ['#00000000', 'Transparent'],
  ].freeze

  def initialize(solid, &on_change)
    @solid = solid
    @on_change = on_change
    @custom_color = nil
    @custom_alpha = 1.0
  end

  def build
    group.tap do |preferences|
      preferences.add(presets_row)

      presets_row.tap do |row|
        row.child = presets_grid

        presets_grid.tap do |grid|
          preset_buttons.each_with_index do |button, index|
            grid.attach(
              button.build,
              index % COLUMNS,
              index / COLUMNS,
              1,
              1,
            )
          end

          grid.attach(
            color_picker_button.build,
            COMMON_COLORS.length % COLUMNS,
            COMMON_COLORS.length / COLUMNS,
            1,
            1,
          )
        end
      end

      update_selection
    end
  end

  def on_change(&block)
    @on_change = block
  end

  def solid = @solid

  def group
    @group ||= Adwaita::PreferencesGroup.new.tap do |preferences|
      preferences.title = 'Solid Color Background'
    end
  end

  def presets_row
    @presets_row ||= Adwaita::ActionRow.new.tap do |row|
      row.activatable = false
      row.selectable = false
    end
  end

  def presets_grid
    @presets_grid ||= Gtk::Grid.new.tap do |grid|
      grid.margin_top = 3
      grid.margin_bottom = 3
      grid.valign = :center
      grid.halign = :center
    end
  end

  def preset_buttons
    @preset_buttons ||= COMMON_COLORS.map do |(packed, name)|
      split_color(packed).then do |(color, alpha)|
        ColorPresetButton.new(
          color:        color,
          alpha:        alpha,
          tooltip_text: name,
        ) { |picked, picked_alpha| on_preset_clicked(picked, picked_alpha) }
      end
    end
  end

  def color_picker_button
    @color_picker_button ||= ColorPickerButton.new { |color, alpha| on_custom_picked(color, alpha) }
  end

  private

    # "#ffd1f0ff" => ["#d1f0ff", 1.0]; a six-digit code is fully opaque.
    def split_color(packed)
      packed.delete_prefix('#').then do |digits|
        if digits.length == 8
          ["##{digits[2..]}", digits[0, 2].to_i(16) / 255.0]
        else
          ["##{digits}", 1.0]
        end
      end
    end

    def on_preset_clicked(color, alpha)
      @solid.color = color
      @solid.alpha = alpha
      update_selection
      notify_change
    end

    def on_custom_picked(color, alpha)
      @custom_color = color
      @custom_alpha = alpha
      on_preset_clicked(color, alpha)
    end

    # At most one of the fifteen cells carries a checkmark, and the chooser's
    # cell carries it only while the current colour is the one it picked.
    def update_selection
      preset_buttons.each { |button| button.selected = matches?(button.color, button.alpha) }
      color_picker_button.selected = !@custom_color.nil? && matches?(@custom_color, @custom_alpha)
    end

    def matches?(color, alpha)
      color.downcase == @solid.color.downcase && (alpha - @solid.alpha).abs < 0.01
    end

    def notify_change
      if @on_change
        @on_change.call(@solid)
      end
    end
end
