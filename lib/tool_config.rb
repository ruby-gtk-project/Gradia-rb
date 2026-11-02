# frozen_string_literal: true

require 'adwaita'
require 'json'
require_relative 'colors'
require_relative 'drawing_actions'
require_relative 'logger'
require_relative 'settings'

# ToolOption is one drawing tool's remembered settings: stroke size, the three
# colours it draws with and the font the text tool uses. Changing one notifies
# its owner, which is how the settings file stays current without the widgets
# knowing about it.
#
# Ported from gradia/backend/tool_config.py (the ToolOption class). Upstream
# keeps the colours as formatted strings rather than Gdk.RGBA objects so that
# an assignment can be compared against the old value cheaply and a no-op
# assignment does not trigger a settings write; the port keeps that.
class ToolOption
  DEFAULT_FONT = 'Adwaita Sans'
  COLOR_PATTERN = /rgba\(([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+)\)/

  attr_reader :mode

  def initialize(
    mode,
    size: 14,
    primary_color: nil,
    fill_color: nil,
    border_color: nil,
    font: nil,
    is_temporary: false,
    &on_change
  )
    @mode = mode
    @size = size
    @primary_color_str = rgba_to_str(
      primary_color || Gdk::RGBA.new(
        0,
        0,
        0,
        1,
      ),
    )
    @fill_color_str = rgba_to_str(
      fill_color || Gdk::RGBA.new(
        1,
        1,
        1,
        1,
      ),
    )
    @border_color_str = rgba_to_str(
      border_color || Gdk::RGBA.new(
        0,
        0,
        0,
        0,
      ),
    )
    @font = font || DEFAULT_FONT
    @is_temporary = is_temporary
    @on_change = on_change
  end

  attr_reader :size, :font

  def size=(value)
    if @size != value
      @size = value
      notify_change
    end
  end

  def primary_color = str_to_rgba(@primary_color_str)
  def fill_color = str_to_rgba(@fill_color_str)
  def border_color = str_to_rgba(@border_color_str)

  def primary_color=(value)
    rgba_to_str(value).then do |new_str|
      unless @primary_color_str == new_str
        @primary_color_str = new_str
        notify_change
      end
    end
  end

  def fill_color=(value)
    rgba_to_str(value).then do |new_str|
      unless @fill_color_str == new_str
        @fill_color_str = new_str
        notify_change
      end
    end
  end

  def border_color=(value)
    rgba_to_str(value).then do |new_str|
      unless @border_color_str == new_str
        @border_color_str = new_str
        notify_change
      end
    end
  end

  def font=(value)
    if @font != value
      @font = value
      notify_change
    end
  end

  def serialize
    JSON.generate(
      {
        'mode'          => @mode.name,
        'size'          => size,
        'primary_color' => Colors.components(primary_color),
        'fill_color'    => Colors.components(fill_color),
        'border_color'  => Colors.components(border_color),
        'font'          => font,
      },
    )
  end

  def self.deserialize(json_str, &on_change)
    JSON.parse(json_str).then do |data|
      new(
        DrawingMode[data.fetch('mode', 'PEN')],
        size:          data.fetch('size', 10),
        primary_color: tuple_to_rgba(data['primary_color']),
        fill_color:    tuple_to_rgba(data['fill_color']),
        border_color:  tuple_to_rgba(data['border_color']),
        font:          data.fetch('font', DEFAULT_FONT),
        &on_change
      )
    end
  end

  def self.tuple_to_rgba(tuple)
    if tuple.is_a?(Array) && tuple.length == 4
      Gdk::RGBA.new(*tuple)
    else
      Gdk::RGBA.new(
        0,
        0,
        0,
        1,
      )
    end
  end

  # A temporary copy drops the change callback, so the tool popovers can show
  # a preview without writing it to the settings.
  def copy(is_temporary: false)
    ToolOption.new(
      @mode,
      size:          size,
      primary_color: primary_color,
      fill_color:    fill_color,
      border_color:  border_color,
      font:          font,
      is_temporary:  is_temporary,
      &callback_for(is_temporary)
    )
  end

  # The silent counterpart of the setters above: the popovers use it while a
  # drag is in flight, so a slider does not write to the settings on every
  # frame.
  def update_without_notify(size: nil, primary_color: nil, fill_color: nil, border_color: nil, font: nil)
    if size
      @size = size
    end
    if primary_color
      @primary_color_str = rgba_to_str(primary_color)
    end
    if fill_color
      @fill_color_str = rgba_to_str(fill_color)
    end
    if border_color
      @border_color_str = rgba_to_str(border_color)
    end
    if font
      @font = font
    end
    self
  end

  private

    def callback_for(is_temporary)
      if is_temporary
        nil
      else
        @on_change
      end
    end

    def notify_change
      if @on_change && !@is_temporary
        @on_change.call(self)
      end
    end

    def rgba_to_str(rgba)
      Colors.components(rgba).then do |(red, green, blue, alpha)|
        format(
          'rgba(%.2f, %.2f, %.2f, %.2f)',
          red,
          green,
          blue,
          alpha,
        )
      end
    end

    def str_to_rgba(string)
      COLOR_PATTERN.match(string).then do |match|
        if match
          Gdk::RGBA.new(*match.captures.map(&:to_f))
        else
          Gdk::RGBA.new(
            0,
            0,
            0,
            1,
          )
        end
      end
    end
end

# ToolOptionsManager owns one ToolOption per drawing mode and keeps them in
# step with the stored tool configuration.
#
# Ported from gradia/backend/tool_config.py (the ToolOptionsManager class).
class ToolOptionsManager
  def initialize(settings: nil, logger: GradiaLogger.new)
    @settings = settings || Settings.new
    @logger = logger
    @tool_configs = {}
    initialize_tools
    load_from_settings
  end

  def tool(mode) = @tool_configs.fetch(mode)

  def export_config
    @tool_configs.to_h { |mode, option| [mode.name, option.serialize] }
  end

  private

    def initialize_tools
      DrawingMode::ALL.each do |mode|
        @tool_configs[mode] = ToolOption.new(mode) { |option| on_tool_changed(option) }
      end
    end

    def load_from_settings
      DrawingMode::ALL.each do |mode|
        @settings.tool_config_item(settings_key(mode)).then do |saved|
          if saved
            restore(mode, saved)
          end
        end
      end
    end

    # A stored config that no longer parses is logged and skipped, leaving the
    # freshly built default in place.
    def restore(mode, saved)
      @tool_configs[mode] = ToolOption.deserialize(saved) { |option| on_tool_changed(option) }
    rescue StandardError => error
      @logger.warning("Failed to load tool config for #{mode.name}", exception: error, show_exception: true)
    end

    def on_tool_changed(option)
      @settings.set_tool_config_item(settings_key(option.mode), option.serialize)
    end

    def settings_key(mode) = "tool_#{mode.name.downcase}"
end

# ToolConfig is one tool's place in the tools grid and which option controls
# the sidebar shows when it is picked.
#
# Ported from gradia/backend/tool_config.py (the ToolConfig class and its
# `get_all_tools_positions` table).
class ToolConfig
  TEXT_COLORS = [
    [Gdk::RGBA.new(
      0.65,
      0.11,
      0.18,
      1,
    ), 'Red'
],
    [Gdk::RGBA.new(
      0.15,
      0.64,
      0.41,
      1,
    ), 'Green'
],
    [Gdk::RGBA.new(
      0.1,
      0.37,
      0.71,
      1,
    ), 'Blue'
],
    [Gdk::RGBA.new(
      0.9,
      0.65,
      0.04,
      1,
    ), 'Yellow'
],
    [Gdk::RGBA.new(
      0,
      0,
      0,
      1,
    ), 'Black'
],
    [Gdk::RGBA.new(
      1.0,
      1.0,
      1.0,
      1,
    ), 'White'
],
  ].freeze

  TEXT_BACKGROUND_COLORS = [
    [Gdk::RGBA.new(
      0.96,
      0.38,
      0.32,
      1,
    ), 'Red'
],
    [Gdk::RGBA.new(
      0.56,
      0.94,
      0.64,
      1,
    ), 'Green'
],
    [Gdk::RGBA.new(
      0.6,
      0.76,
      0.95,
      1,
    ), 'Blue'
],
    [Gdk::RGBA.new(
      0.98,
      0.94,
      0.42,
      1,
    ), 'Yellow'
],
    [Gdk::RGBA.new(
      1.0,
      1.0,
      1.0,
      1,
    ), 'White'
],
    [Gdk::RGBA.new(
      0,
      0,
      0,
      1,
    ), 'Black'
],
    [Gdk::RGBA.new(
      0,
      0,
      0,
      0,
    ), 'Transparent'
],
  ].freeze

  HIGHLIGHTER_COLORS = [
    [Gdk::RGBA.new(
      0.88,
      0.11,
      0.14,
      0.4,
    ), 'Red'
],
    [Gdk::RGBA.new(
      0.18,
      0.76,
      0.49,
      0.4,
    ), 'Green'
],
    [Gdk::RGBA.new(
      0.21,
      0.52,
      0.89,
      0.4,
    ), 'Blue'
],
    [Gdk::RGBA.new(
      0.96,
      0.83,
      0.18,
      0.4,
    ), 'Yellow'
],
    [Gdk::RGBA.new(
      0.51,
      0.24,
      0.61,
      0.4,
    ), 'Purple'
],
    [Gdk::RGBA.new(
      1.0,
      1.0,
      1.0,
      0.4,
    ), 'White'
],
  ].freeze

  attr_reader :mode, :icon, :column, :row, :shown_stack, :primary_color_list, :secondary_color_list

  def initialize(
    mode,
    icon,
    column:,
    row:,
    shown_stack: 'empty',
    has_scale: false,
    has_primary_color: false,
    match_primary_to_secondary: false,
    primary_color_list: nil,
    secondary_color_list: nil
  )
    @mode = mode
    @icon = icon
    @column = column
    @row = row
    @shown_stack = shown_stack
    @has_scale = has_scale
    @has_primary_color = has_primary_color
    @match_primary_to_secondary = match_primary_to_secondary
    @primary_color_list = primary_color_list
    @secondary_color_list = secondary_color_list
  end

  def scale? = @has_scale
  def primary_color? = @has_primary_color
  def match_primary_to_secondary? = @match_primary_to_secondary

  # Two rows of five, in the order the grid lays them out.
  def self.all_tools_positions
    [
      new(DrawingMode::SELECT, 'pointer-primary-click-symbolic', column: 0, row: 0),
      new(DrawingMode::PEN, 'edit-symbolic', column: 1, row: 0, has_scale: true, has_primary_color: true),
      new(
        DrawingMode::TEXT,
        'text-insert2-symbolic',
        column:               2,
        row:                  0,
        shown_stack:          'text',
        has_primary_color:    true,
        primary_color_list:   TEXT_COLORS,
        secondary_color_list: TEXT_BACKGROUND_COLORS,
      ),
      new(DrawingMode::LINE, 'draw-line-symbolic', column: 3, row: 0, has_scale: true, has_primary_color: true),
      new(DrawingMode::ARROW, 'arrow1-top-right-symbolic', column: 4, row: 0, has_scale: true, has_primary_color: true),
      new(
        DrawingMode::SQUARE,
        'box-small-outline-symbolic',
        column:            0,
        row:               1,
        shown_stack:       'fill',
        has_scale:         true,
        has_primary_color: true,
      ),
      new(
        DrawingMode::CIRCLE,
        'circle-outline-thick-symbolic',
        column:            1,
        row:               1,
        shown_stack:       'fill',
        has_scale:         true,
        has_primary_color: true,
      ),
      new(
        DrawingMode::HIGHLIGHTER,
        'marker-symbolic',
        column:             2,
        row:                1,
        has_scale:          true,
        has_primary_color:  true,
        primary_color_list: HIGHLIGHTER_COLORS,
      ),
      new(DrawingMode::CENSOR, 'checkerboard-big-symbolic', column: 3, row: 1),
      new(
        DrawingMode::NUMBER,
        'one-circle-symbolic',
        column:                     4,
        row:                        1,
        shown_stack:                'fill-border',
        has_scale:                  true,
        has_primary_color:          true,
        match_primary_to_secondary: true,
        primary_color_list:         TEXT_COLORS,
        secondary_color_list:       TEXT_BACKGROUND_COLORS,
      ),
    ]
  end
end
