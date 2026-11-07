# frozen_string_literal: true

require 'adwaita'
require_relative 'drawing_actions'
require_relative 'tool_config'
require_relative 'settings'

# DrawingToolsGrid is the two-row grid of circular toggle buttons that picks
# the active annotation tool: exactly one of the ten is active at a time, and
# picking one restores it as the mode the settings remember.
#
# Ported from gradia/ui/widget/drawing_tools_grid.py. Upstream subclasses
# Gtk.Grid and publishes the pick as a `tool-changed` GObject signal carrying
# the plain-Ruby ToolConfig; a Ruby class cannot register a signal carrying a
# non-GObject payload on a boxed Gtk type, so the pick is published as a plain
# `on_tool_changed` callback instead, the same substitution
# lib/toggle_group.rb makes for its own GObject property.
class DrawingToolsGrid
  ROW_SPACING = 9
  COLUMN_SPACING = 18
  BUTTON_SIZE = 40
  ICON_PIXEL_SIZE = 18

  def initialize(settings: nil, &on_tool_changed)
    @settings = settings || Settings.new
    @on_tool_changed = on_tool_changed
    @buttons = {}
    @tool_configs = {}
    @current_tool = nil
  end

  def build
    grid.tap do |g|
      g.row_spacing = ROW_SPACING
      g.column_spacing = COLUMN_SPACING
      g.column_homogeneous = true
      g.row_homogeneous = true

      ToolConfig.all_tools_positions.each do |tool_config|
        @tool_configs[tool_config.mode] = tool_config

        button_for(tool_config).tap do |button|
          @buttons[tool_config.mode] = button
          g.attach(button, tool_config.column, tool_config.row, 1, 1)
        end
      end

      select_initial_tool
    end
  end

  def current_tool = @tool_configs[@current_tool]

  def set_current_tool(mode) = select_tool(mode)

  def set_secondary_highlight_tool(mode)
    @buttons.each_value do |button|
      button.add_css_class('flat')
      button.remove_css_class('accent')
    end
    if mode && @buttons.key?(mode)
      @buttons.fetch(mode).remove_css_class('flat')
      @buttons.fetch(mode).add_css_class('accent')
    end
  end

  private

    def button_for(tool_config)
      Gtk::ToggleButton.new.tap do |button|
        button.tooltip_text = tool_config.mode.label
        button.width_request = BUTTON_SIZE
        button.height_request = BUTTON_SIZE
        button.css_classes = ['flat', 'circular']
        button.icon_name = tool_config.icon
        button.first_child&.pixel_size = ICON_PIXEL_SIZE
        @handler_ids ||= {}
        @handler_ids[button] = button.signal_connect('toggled') { |btn| on_button_toggled(btn, tool_config.mode) }
      end
    end

    def on_button_toggled(button, mode)
      if button.active?
        deactivate_other_buttons(mode)
        old_tool = @current_tool
        @current_tool = mode
        @settings.draw_mode = mode.name
        if old_tool != mode
          @on_tool_changed&.call(@tool_configs.fetch(mode))
        end
      elsif @current_tool == mode
        without_toggled_handler(button) { button.active = true }
      end
    end

    def deactivate_other_buttons(mode)
      @buttons.each do |other_mode, other_button|
        if other_mode != mode && other_button.active?
          without_toggled_handler(other_button) { other_button.active = false }
        end
      end
    end

    def without_toggled_handler(button)
      button.signal_handler_block(@handler_ids.fetch(button))
      yield
      button.signal_handler_unblock(@handler_ids.fetch(button))
    end

    def select_tool(mode)
      if @buttons.key?(mode)
        @buttons.fetch(mode).active = true
      end
    end

    def select_initial_tool
      DrawingMode.find(@settings.draw_mode).then do |initial_mode|
        if initial_mode
          select_tool(initial_mode)
          @current_tool = initial_mode
          @on_tool_changed&.call(@tool_configs.fetch(initial_mode))
        end
      end
    end

    def grid = @grid ||= Gtk::Grid.new
end
