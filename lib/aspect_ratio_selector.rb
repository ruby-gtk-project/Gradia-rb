# frozen_string_literal: true

require 'adwaita'

# AspectRatioSelector is the sidebar's Aspect Ratio row: it shows the ratio in
# force and drops a popover with ten presets and a width:height pair for
# anything else.
#
# Ported from gradia/ui/widget/background_aspect_ratio_selector.py. Upstream
# publishes the choice as an `aspect-ratio` GObject property and a
# `ratio-changed` signal; a Ruby class cannot register either on a boxed Gtk
# type, so the ratio is a plain accessor plus an `on_change` callback.
class AspectRatioSelector
  COLUMNS = 2

  PRESET_RATIOS = [
    ['Auto', ''],
    ['1:1', '1:1'],
    ['16:9', '16:9'],
    ['4:3', '4:3'],
    ['3:2', '3:2'],
    ['2:3', '2:3'],
    ['3:4', '3:4'],
    ['9:16', '9:16'],
    ['21:9', '21:9'],
    ['1.618:1', '1.618:1'],
  ].freeze

  def initialize(ratio: '', &on_change)
    @ratio = ratio
    @on_change = on_change
  end

  def build
    row.tap do |action_row|
      action_row.add_suffix(suffix_box)

      suffix_box.tap do |box|
        box.append(value_label)
        box.append(dropdown_arrow)
      end

      popover.tap do |pop|
        pop.set_parent(dropdown_arrow)
        pop.child = popover_box

        popover_box.tap do |box|
          box.append(preset_grid)
          box.append(Gtk::Separator.new(:horizontal))
          box.append(custom_label)
          box.append(inputs_box)
          box.append(set_button)

          preset_grid.tap do |grid|
            preset_buttons.each_with_index do |(button, value), index|
              grid.attach(
                button,
                index % COLUMNS,
                index / COLUMNS,
                1,
                1,
              )
              button.signal_connect('clicked') { on_preset_selected(value, button.label) }
            end
          end

          inputs_box.tap do |inputs|
            inputs.append(width_box)
            inputs.append(colon_label)
            inputs.append(height_box)

            width_box.tap do |box_|
              box_.append(width_heading)
              box_.append(width_input)
            end

            height_box.tap do |box_|
              box_.append(height_heading)
              box_.append(height_input)
            end
          end

          set_button.tap do |button|
            button.signal_connect('clicked') { on_custom_ratio_set }
          end
        end
      end

      action_row.signal_connect('activated') { popover.popup }

      self.ratio = @ratio
    end
  end

  def on_change(&block)
    @on_change = block
  end

  def ratio = @ratio

  # Assigning a ratio moves the label and, for a custom one, fills the two
  # entries so the popover opens on what is in force.
  def ratio=(value)
    @ratio = value.to_s
    PRESET_RATIOS.find { |(_label, preset)| preset == @ratio }.then do |match|
      if match
        value_label.text = match.first
      else
        show_custom_ratio
      end
    end
  end

  def row
    @row ||= Adwaita::ActionRow.new.tap do |action_row|
      action_row.title = '_Aspect Ratio'
      action_row.use_underline = true
      action_row.activatable = true
    end
  end

  def suffix_box = @suffix_box ||= Gtk::Box.new(:horizontal, 8)

  def value_label = @value_label ||= Gtk::Label.new('Auto')

  def dropdown_arrow
    @dropdown_arrow ||= Gtk::Image.new.tap do |arrow|
      arrow.icon_name = 'pan-down-symbolic'
    end
  end

  def popover
    @popover ||= Gtk::Popover.new.tap do |pop|
      pop.has_arrow = true
      pop.autohide = true
    end
  end

  def popover_box
    @popover_box ||= Gtk::Box.new(:vertical, 12).tap do |box|
      box.margin_start = 8
      box.margin_end = 8
      box.margin_top = 8
      box.margin_bottom = 8
    end
  end

  def preset_grid
    @preset_grid ||= Gtk::Grid.new.tap do |grid|
      grid.row_spacing = 8
      grid.column_spacing = 8
      grid.column_homogeneous = true
    end
  end

  # [[button, value], …] in preset order.
  def preset_buttons
    @preset_buttons ||= PRESET_RATIOS.map do |(label, value)|
      [
        Gtk::Button.new.tap do |button|
          button.label = label
          button.add_css_class('flat')
          button.set_size_request(80, 36)
        end,
        value,
      ]
    end
  end

  def custom_label
    @custom_label ||= Gtk::Label.new('Custom Ratio').tap do |label|
      label.halign = :start
      label.add_css_class('heading')
    end
  end

  def inputs_box = @inputs_box ||= Gtk::Box.new(:horizontal, 8)

  def width_box = @width_box ||= Gtk::Box.new(:vertical, 4)

  def height_box = @height_box ||= Gtk::Box.new(:vertical, 4)

  def width_heading = @width_heading ||= caption_label('Width')

  def height_heading = @height_heading ||= caption_label('Height')

  def width_input = @width_input ||= ratio_entry

  def height_input = @height_input ||= ratio_entry

  def colon_label
    @colon_label ||= Gtk::Label.new(':').tap do |label|
      label.valign = :end
      label.margin_bottom = 8
    end
  end

  def set_button
    @set_button ||= Gtk::Button.new.tap do |button|
      button.label = 'Set'
      button.add_css_class('suggested-action')
    end
  end

  private

    def caption_label(text)
      Gtk::Label.new(text).tap do |label|
        label.halign = :start
        label.add_css_class('caption')
      end
    end

    def ratio_entry
      Gtk::Entry.new.tap do |entry|
        entry.input_purpose = :number
        entry.max_length = 4
        entry.width_chars = 7
        entry.max_width_chars = 5
      end
    end

    def show_custom_ratio
      if @ratio.include?(':')
        value_label.text = @ratio
        @ratio.split(':', 2).then do |(width, height)|
          width_input.text = width.to_s
          height_input.text = height.to_s
        end
      end
    end

    def on_preset_selected(value, label)
      @ratio = value
      value_label.text = label
      popover.popdown
      notify_change
    end

    # Both sides have to be whole positive numbers; anything else leaves the
    # popover open and the ratio alone, exactly as upstream does.
    def on_custom_ratio_set
      [width_input.text.strip, height_input.text.strip].then do |(width, height)|
        if positive_integer?(width) && positive_integer?(height)
          @ratio = "#{width.to_i}:#{height.to_i}"
          value_label.text = @ratio
          popover.popdown
          notify_change
        end
      end
    end

    def positive_integer?(text) = text.match?(/\A\d+\z/) && text.to_i.positive?

    def notify_change
      if @on_change
        @on_change.call(@ratio)
      end
    end
end
