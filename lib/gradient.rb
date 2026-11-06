# frozen_string_literal: true

require 'adwaita'
require 'json'
require_relative 'background'
require_relative 'color_conversions'

# Gradient is the serialisable description of a gradient background: a mode, a
# list of (position, "rgb(r,g,b)") steps and an angle. GradientBackground
# renders one.
#
# Ported from gradia/graphics/gradient.py. Upstream renders through a bundled C
# extension (gradia/graphics/gradient_gen.c) because PIL has no gradient
# primitive; Cairo does, so the linear and radial modes are Cairo gradient
# patterns here. Cairo has no conic gradient, so that one is swept as wedges —
# with the same step remapping upstream applies before handing conic steps to C,
# which is what makes the seam land behind the start of the sweep.
class Gradient
  MODES = %w[linear conic radial].freeze

  DEFAULT_STEPS = [[0.0, 'rgb(87,227,137)'], [1.0, 'rgb(53,132,228)']].freeze
  DEFAULT_ANGLE = 135.0

  attr_accessor :mode, :steps, :angle, :name

  def initialize(mode: 'linear', steps: nil, angle: DEFAULT_ANGLE, name: nil)
    @mode = mode
    @steps = (steps || DEFAULT_STEPS).map { |(position, color)| [position.to_f, color] }
    @angle = angle
    @name = name
  end

  def to_json(*_args)
    JSON.generate({ 'mode' => @mode, 'steps' => @steps, 'angle' => @angle })
  end

  # Upstream swallows every parse failure and falls back to the default
  # gradient rather than leaving the sidebar without one.
  def self.from_json(json_str)
    JSON.parse(json_str).then do |data|
      new(
        mode:  data.fetch('mode', 'linear'),
        steps: data.fetch('steps', DEFAULT_STEPS),
        angle: data.fetch('angle', DEFAULT_ANGLE),
      )
    end
  rescue StandardError
    new
  end

  def to_css
    steps_str = @steps.map { |(position, color)| format('%s %.2f%%', color, position * 100) }.join(', ')

    case @mode
    when 'linear' then format('linear-gradient(%.2fdeg, %s)', @angle, steps_str)
    when 'conic' then format('conic-gradient(from %.2fdeg, %s)', @angle, steps_str)
    when 'radial' then "radial-gradient(circle, #{steps_str})"
    else ''
    end
  end

  def dup = self.class.new(mode: @mode, steps: @steps.map(&:dup), angle: @angle, name: @name)
end

# GradientBackground paints a Gradient onto a Cairo surface.
class GradientBackground < Background
  # How many wedges the conic sweep is cut into. 720 is half a degree each,
  # which is below a pixel of arc at the sizes the app exports.
  CONIC_SEGMENTS = 720

  attr_accessor :gradient

  def initialize(gradient: nil)
    super()
    @gradient = gradient || Gradient.new
  end

  def self.from_json(json_str) = new(gradient: Gradient.from_json(json_str))

  def to_json(*_args) = @gradient.to_json

  def name = 'Gradient'

  def prepare_image(width, height)
    blank_surface(width, height).tap do |surface|
      Cairo::Context.new(surface).tap do |context|
        context.operator = Cairo::OPERATOR_SOURCE

        case @gradient.mode
        when 'conic' then paint_conic(context, surface.width, surface.height)
        when 'radial' then paint_pattern(context, radial_pattern(surface.width, surface.height), surface)
        else paint_pattern(context, linear_pattern(surface.width, surface.height), surface)
        end
      end
    end
  end

  # The steps as [position, [r, g, b]] with the channels in 0.0–1.0, sorted by
  # position — the form both the Cairo patterns and the conic sweep want.
  def normalized_steps(steps = @gradient.steps)
    steps.map do |(position, color)|
      [position.to_f, Colors.parse_rgb_string(color).map { |channel| channel / 255.0 }]
    end.sort_by(&:first)
  end

  # Upstream shifts conic steps by the angle, squeezes them into the middle 90%
  # of the sweep and repeats the first colour at the end, so the wrap-around
  # seam is a blend rather than a hard edge.
  def conic_steps
    offset = (@gradient.angle % 360.0) / 360.0
    @gradient.steps
      .map { |(position, color)| [(((position.to_f * 0.9) + 0.05 + offset) % 1.0), color] }
      .sort_by(&:first)
      .then { |shifted| shifted + [[1.0, shifted.first.last]] }
  end

  private

    def paint_pattern(context, pattern, surface)
      context.set_source(pattern)
      context.rectangle(
        0,
        0,
        surface.width,
        surface.height,
      )
      context.fill
    end

    # CSS angle semantics, which is what Gradient#to_css promises the preview:
    # 0deg points up, and the angle grows clockwise.
    def linear_pattern(width, height)
      radians = @gradient.angle * Math::PI / 180.0
      dx = Math.sin(radians)
      dy = -Math.cos(radians)
      length = (width * dx).abs + (height * dy).abs
      cx = width / 2.0
      cy = height / 2.0

      Cairo::LinearPattern.new(
        cx - (dx * length / 2.0),
        cy - (dy * length / 2.0),
        cx + (dx * length / 2.0),
        cy + (dy * length / 2.0),
      ).tap { |pattern| add_stops(pattern, normalized_steps) }
    end

    # CSS `radial-gradient(circle, …)` without an extent keyword reaches the
    # farthest corner, which from the centre is half the diagonal.
    def radial_pattern(width, height)
      (Math.hypot(width, height) / 2.0).then do |radius|
        Cairo::RadialPattern.new(
          width / 2.0,
          height / 2.0,
          0,
          width / 2.0,
          height / 2.0,
          radius,
        ).tap { |pattern| add_stops(pattern, normalized_steps) }
      end
    end

    def add_stops(pattern, stops)
      stops.each do |(position, (red, green, blue))|
        pattern.add_color_stop_rgba(
          position,
          red,
          green,
          blue,
          1.0,
        )
      end
    end

    def paint_conic(context, width, height)
      normalized_steps(conic_steps).then do |stops|
        radius = Math.hypot(width, height)
        cx = width / 2.0
        cy = height / 2.0

        CONIC_SEGMENTS.times do |index|
          wedge(
            context,
            cx,
            cy,
            radius,
            index,
            stops,
          )
        end
      end
    end

    # One wedge, drawn a hair wider than its share of the circle so the seams
    # between neighbours do not show as hairlines.
    def wedge(context, cx, cy, radius, index, stops)
      sweep = 2 * Math::PI / CONIC_SEGMENTS
      start_angle = (index * sweep) - (Math::PI / 2)
      midpoint = (index + 0.5) / CONIC_SEGMENTS

      color_at(stops, midpoint).then do |(red, green, blue)|
        context.set_source_rgba(
          red,
          green,
          blue,
          1.0,
        )
        context.move_to(cx, cy)
        context.arc(
          cx,
          cy,
          radius,
          start_angle,
          start_angle + sweep + 0.002,
        )
        context.close_path
        context.fill
      end
    end

    # Linear interpolation between the two stops a position falls between,
    # clamped to the end stops outside the range they cover.
    def color_at(stops, position)
      if position <= stops.first.first
        stops.first.last
      elsif position >= stops.last.first
        stops.last.last
      else
        between(stops, position)
      end
    end

    def between(stops, position)
      stops.each_cons(2) do |(left_position, left_color), (right_position, right_color)|
        if position >= left_position && position <= right_position
          span = right_position - left_position
          if span.zero?
            break left_color
          end

          t = (position - left_position) / span
          break left_color.zip(right_color).map { |(a, b)| a + ((b - a) * t) }
        end
      end
    end
end
