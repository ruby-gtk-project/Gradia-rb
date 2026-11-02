# frozen_string_literal: true

require 'adwaita'

# AspectRatioButton is the crop toolbar's ratio button: a flat icon button
# whose popover lists six crop ratios, and whose icon becomes the one that was
# picked.
#
# Ported from gradia/ui/widget/aspect_ratio_button.py. Upstream activates the
# window's `aspect-ratio-crop` action itself by looking the action up on its
# root; the port takes the handler as a callback so the button does not have to
# know which window it ends up in, and the parent wires it to that action.
class AspectRatioButton
  DEFAULT_ICON_NAME = 'aspect-ratio-symbolic'

  # Label, icon, and the ratio the crop overlay is clamped to — 0.0 meaning
  # no clamp at all.
  ASPECT_RATIOS = [
    ['Free', 'aspect-ratio-free-symbolic', 0.0],
    ['Square', 'aspect-ratio-square-symbolic', 1.0],
    ['4:3', 'aspect-ratio-4to3-symbolic', 4.0 / 3.0],
    ['3:2', 'aspect-ratio-3to2-symbolic', 3.0 / 2.0],
    ['5:4', 'aspect-ratio-5to4-symbolic', 5.0 / 4.0],
    ['16:9', 'aspect-ratio-16to9-symbolic', 16.0 / 9.0],
  ].freeze

  def initialize(&on_select)
    @on_select = on_select
  end

  def build
    button.tap do |ratio_button|
      ratio_button.child = icon

      popover.tap do |pop|
        pop.set_parent(ratio_button)
        pop.child = popover_box

        popover_box.tap do |box|
          ratio_buttons.each do |(entry, icon_name, ratio)|
            box.append(entry)
            entry.signal_connect('clicked') { on_ratio_selected(ratio, icon_name) }
          end
        end
      end

      ratio_button.signal_connect('clicked') { popover.popup }
    end
  end

  def on_select(&block)
    @on_select = block
  end

  def button
    @button ||= Gtk::Button.new.tap do |ratio_button|
      ratio_button.tooltip_text = 'Aspect Ratio'
      ratio_button.add_css_class('flat')
    end
  end

  def icon
    @icon ||= Gtk::Image.new.tap do |image|
      image.icon_name = DEFAULT_ICON_NAME
    end
  end

  def popover
    @popover ||= Gtk::Popover.new.tap do |pop|
      pop.position = :top
    end
  end

  def popover_box
    @popover_box ||= Gtk::Box.new(:vertical, 6).tap do |box|
      box.margin_top = 6
      box.margin_bottom = 6
      box.margin_start = 6
      box.margin_end = 6
    end
  end

  # [[button, icon name, ratio], …] in menu order.
  def ratio_buttons
    @ratio_buttons ||= ASPECT_RATIOS.map do |(label, icon_name, ratio)|
      [ratio_entry(label, icon_name), icon_name, ratio]
    end
  end

  private

    def ratio_entry(label, icon_name)
      Gtk::Button.new.tap do |entry|
        entry.has_frame = false
        entry.child = entry_box(label, icon_name)
      end
    end

    def entry_box(label, icon_name)
      Gtk::Box.new(:horizontal, 12).tap do |box|
        box.halign = :start
        box.append(entry_icon(icon_name))
        box.append(entry_label(label))
      end
    end

    def entry_icon(icon_name)
      Gtk::Image.new.tap do |image|
        image.icon_name = icon_name
        image.icon_size = :normal
      end
    end

    def entry_label(label)
      Gtk::Label.new(label).tap do |text|
        text.halign = :start
      end
    end

    def on_ratio_selected(ratio, icon_name)
      icon.icon_name = icon_name
      popover.popdown

      if @on_select
        @on_select.call(ratio)
      end
    end
end
