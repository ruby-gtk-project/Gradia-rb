# frozen_string_literal: true

require 'adwaita'
require 'json'
require_relative 'background'
require_relative 'color_conversions'

# SolidBackground fills the whole canvas with one colour at one opacity.
#
# Ported from gradia/graphics/solid.py (the SolidBackground class; the selector
# widget from the same file lives in lib/solid_selector.rb).
class SolidBackground < Background
  DEFAULT_COLOR = '#4A90E2'
  DEFAULT_ALPHA = 1.0

  attr_accessor :color, :alpha

  def initialize(color: DEFAULT_COLOR, alpha: DEFAULT_ALPHA)
    super()
    @color = color
    @alpha = alpha
  end

  def self.from_json(json_str)
    JSON.parse(json_str).then do |data|
      new(color: data.fetch('color', DEFAULT_COLOR), alpha: data.fetch('alpha', DEFAULT_ALPHA))
    end
  rescue JSON::ParserError
    new
  end

  def to_json(*_args)
    JSON.generate({ 'type' => 'solid', 'color' => @color, 'alpha' => @alpha })
  end

  def name = "solid-#{@color}-#{@alpha}"

  def prepare_image(width, height)
    blank_surface(width, height).tap do |surface|
      Colors.hex_to_rgb(@color).then do |(red, green, blue)|
        Cairo::Context.new(surface).tap do |context|
          context.set_source_rgba(
            red / 255.0,
            green / 255.0,
            blue / 255.0,
            @alpha,
          )
          context.operator = Cairo::OPERATOR_SOURCE
          context.paint
        end
      end
    end
  end
end
