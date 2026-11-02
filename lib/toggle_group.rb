# frozen_string_literal: true

require 'adwaita'

# ToggleGroup is the background-mode picker: four mutually exclusive toggles
# that wrap onto a second line when the sidebar is narrow.
#
# Ported from gradia/ui/widget/toggle_group.py. Upstream subclasses Gtk.Box and
# publishes the choice as an `active-name` GObject property so GSettings can
# bind to it; a Ruby class cannot register properties on a boxed Gtk type, so
# the choice is published as a plain reader plus an `on_change` callback, and
# Settings#bind_toggle_group drives it through those.
class ToggleGroup
  TOGGLES = [
    ['none', '_None'],
    ['solid', '_Solid'],
    ['gradient', '_Gradient'],
    ['image', '_Image'],
  ].freeze

  def initialize(&on_change)
    @on_change = on_change
    @active_name = ''
    @updating = false
  end

  def build
    box.tap do |container|
      container.append(flow_box)

      flow_box.tap do |flow|
        TOGGLES.each do |(name, _label)|
          flow.append(toggle_buttons.fetch(name))

          toggle_buttons.fetch(name).tap do |toggle|
            toggle.signal_connect('toggled') { |button| on_toggled(button, name) }
          end
        end
      end
    end
  end

  # nil rather than the empty string when nothing has been picked yet, which
  # is what upstream's getter does.
  def active_name
    if @active_name.empty?
      nil
    else
      @active_name
    end
  end

  def active_name=(name)
    if toggle_buttons.key?(name) && @active_name != name
      select(name)
    end
  end

  def on_change(&block)
    @on_change = block
  end

  def box
    @box ||= Gtk::Box.new(:vertical, 0)
  end

  def flow_box
    @flow_box ||= Gtk::FlowBox.new.tap do |flow|
      flow.max_children_per_line = 4
      flow.min_children_per_line = 2
      flow.homogeneous = true
      flow.row_spacing = 10
      flow.column_spacing = 8
    end
  end

  def toggle_buttons
    @toggle_buttons ||= TOGGLES.to_h do |(name, label)|
      [
        name,
        Gtk::ToggleButton.new.tap do |toggle|
          toggle.label = label
          toggle.use_underline = true
        end,
      ]
    end
  end

  private

    # Turning a toggle on turns the others off; turning the active one off is
    # refused, so the group always has exactly one choice.
    def on_toggled(button, name)
      unless @updating
        if button.active?
          activate(name)
        else
          keep_active(button, name)
        end
      end
    end

    def activate(name)
      without_recursion do
        toggle_buttons.each do |(toggle_name, toggle)|
          unless toggle_name == name
            toggle.active = false
          end
        end
      end

      @active_name = name
      notify_change
    end

    def keep_active(button, name)
      if @active_name == name
        without_recursion { button.active = true }
      end
    end

    def select(name)
      @active_name = name
      without_recursion do
        toggle_buttons.each { |(toggle_name, toggle)| toggle.active = (toggle_name == name) }
      end
      notify_change
    end

    def without_recursion
      @updating = true
      yield
      @updating = false
    end

    def notify_change
      if @on_change
        @on_change.call(active_name)
      end
    end
end
