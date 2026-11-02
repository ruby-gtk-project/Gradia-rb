# frozen_string_literal: true

require 'adwaita'
require_relative 'colors'
require_relative 'logger'

# DrawingMode is one of the ten annotation tools: its stable name (what the
# settings store and what the tool presets key on), its translated label, and
# the keys that select it.
#
# Ported from gradia/overlay/drawing_actions.py (the DrawingMode enum and the
# `_shortcuts` table bolted onto it below the class body).
class DrawingMode
  attr_reader :name, :label, :shortcuts

  def initialize(name, label, shortcuts)
    @name = name
    @label = label
    @shortcuts = shortcuts
  end

  def to_s = @name
  def ==(other) = other.is_a?(DrawingMode) && other.name == @name
  alias eql? ==
  def hash = @name.hash

  SELECT      = new('SELECT', 'Select', %w[0 KP_0 grave s])
  PEN         = new('PEN', 'Pen', %w[1 KP_1 d p])
  TEXT        = new('TEXT', 'Text', %w[2 KP_2 t])
  LINE        = new('LINE', 'Line', %w[3 KP_3 l])
  ARROW       = new('ARROW', 'Arrow', %w[4 KP_4 a])
  SQUARE      = new('SQUARE', 'Rectangle', %w[5 KP_5 r])
  CIRCLE      = new('CIRCLE', 'Oval', %w[6 KP_6 o])
  HIGHLIGHTER = new('HIGHLIGHTER', 'Highlighter', %w[7 KP_7 h])
  CENSOR      = new('CENSOR', 'Censor', %w[8 KP_8 c])
  NUMBER      = new('NUMBER', 'Number', %w[9 KP_9 n])

  ALL = [SELECT, PEN, TEXT, LINE, ARROW, SQUARE, CIRCLE, HIGHLIGHTER, CENSOR, NUMBER].freeze

  BY_NAME = ALL.to_h { |mode| [mode.name, mode] }.freeze

  def self.[](name) = BY_NAME.fetch(name.to_s)

  def self.find(name) = BY_NAME[name.to_s]
end

# QuadBounds is the four corners an action occupies. A rectangle for most
# tools, a rotated quad for lines and arrows, which is what lets the selection
# outline hug a diagonal arrow instead of boxing it.
#
# Ported from gradia/overlay/drawing_actions.py (the QuadBounds class).
class QuadBounds
  attr_reader :p1, :p2, :p3, :p4

  def initialize(p1, p2, p3, p4)
    @p1 = p1
    @p2 = p2
    @p3 = p3
    @p4 = p4
  end

  def self.from_rect(min_x, min_y, max_x, max_y)
    new(
      [min_x, min_y],
      [max_x, min_y],
      [max_x, max_y],
      [min_x, max_y],
    )
  end

  def self.from_start_end(start_point, end_point)
    from_rect(
      [start_point[0], end_point[0]].min,
      [start_point[1], end_point[1]].min,
      [start_point[0], end_point[0]].max,
      [start_point[1], end_point[1]].max,
    )
  end

  def points = [@p1, @p2, @p3, @p4]

  def bounding_rect
    points.transpose.then do |(xs, ys)|
      [xs.min, ys.min, xs.max, ys.max]
    end
  end
end

# DrawingAction is one annotation on the image: it knows how to draw itself
# into a Cairo context, what area it covers in image coordinates, whether a
# click landed on it, and how to move.
#
# Ported from gradia/overlay/drawing_actions.py (the DrawingAction base class).
# The `image_to_widget_coords` argument every `draw` takes is the overlay's
# coordinate transform, a callable of (x, y) returning widget coordinates, and
# `scale` is the zoom the overlay is drawing at.
class DrawingAction
  attr_reader :options

  def draw(context, image_to_widget_coords, scale)
    raise NotImplementedError, "#{self.class} must implement draw(#{context}, #{image_to_widget_coords}, #{scale})"
  end

  def bounds
    raise NotImplementedError, "#{self.class} must implement bounds"
  end

  def translate(dx, dy)
    raise NotImplementedError, "#{self.class} must implement translate(#{dx}, #{dy})"
  end

  def contains_point?(x_img, y_img)
    bounds.bounding_rect.then do |(min_x, min_y, max_x, max_y)|
      x_img >= min_x && x_img <= max_x && y_img >= min_y && y_img <= max_y
    end
  end

  def drawing_mode = @options.mode

  # A light shadow under dark ink and a dark one under light ink, so the drop
  # shadow is visible whatever the annotation colour is.
  def shadow_color(color)
    Colors.components(color).then do |(red, green, blue, _alpha)|
      if (0.299 * red) + (0.587 * green) + (0.114 * blue) < 0.5
        [1.0, 1.0, 1.0, 0.05]
      else
        [0.0, 0.0, 0.0, 0.3]
      end
    end
  end

  private

    # Cairo's set_source_rgba takes four separate channels; upstream splats a
    # Gdk.RGBA into it, which the Ruby binding does not allow.
    def set_color(context, color)
      Colors.components(color).then do |(red, green, blue, alpha)|
        context.set_source_rgba(
          red,
          green,
          blue,
          alpha,
        )
      end
    end

    def visible_color?(color) = Colors.has_visible_color?(color)
end

# StrokeAction is a freehand pen stroke, smoothed through the midpoints of the
# captured samples so the line does not show the sampling rate.
#
# Ported from gradia/overlay/drawing_actions.py (the StrokeAction class).
class StrokeAction < DrawingAction
  attr_reader :stroke

  def initialize(stroke, options)
    super()
    @stroke = stroke
    @options = options
    @bounds = nil
  end

  def draw(context, image_to_widget_coords, scale)
    if @stroke.length >= 2
      stroke_path(context, @stroke.map { |(x, y)| image_to_widget_coords.call(x, y) }, scale)
    end
  end

  def bounds
    @bounds ||= bounds_from_stroke(@options.size / 2)
  end

  def translate(dx, dy)
    @stroke = @stroke.map { |(x, y)| [x + dx, y + dy] }
    @bounds = nil
  end

  private

    def stroke_path(context, coords, scale)
      build_path(context, coords)
      set_color(context, @options.primary_color)
      context.line_width = @options.size * scale
      context.stroke
    end

    def build_path(context, coords)
      context.line_cap = Cairo::LINE_CAP_ROUND
      context.line_join = Cairo::LINE_JOIN_ROUND
      context.move_to(*coords.first)

      if coords.length <= 2
        short_path(context, coords)
      else
        smooth_path(context, coords)
      end
    end

    def short_path(context, coords)
      if coords.length == 2
        context.line_to(*coords.last)
      end
    end

    # Each sample is a control point and the midpoint to the next one is the
    # curve's end, which is upstream's quadratic-through-midpoints smoothing.
    def smooth_path(context, coords)
      coords.each_cons(2).drop(1).each do |((x1, y1), (x2, y2))|
        context.curve_to(
          x1,
          y1,
          x1,
          y1,
          (x1 + x2) * 0.5,
          (y1 + y2) * 0.5,
        )
      end
      context.line_to(*coords.last)
    end

    def bounds_from_stroke(padding)
      if @stroke.empty?
        QuadBounds.from_rect(
          0,
          0,
          0,
          0,
        )
      else
        @stroke.transpose.then do |(xs, ys)|
          QuadBounds.from_rect(
            xs.min - padding,
            ys.min - padding,
            xs.max + padding,
            ys.max + padding,
          )
        end
      end
    end
end

# ArrowAction is a straight shaft with a two-stroke head at the far end. Its
# head shrinks on short arrows so a tiny arrow is not all head.
#
# Ported from gradia/overlay/drawing_actions.py (the ArrowAction class).
class ArrowAction < DrawingAction
  ARROW_HEAD_SIZE_MULTIPLIER = 3
  MIN_DISTANCE_THRESHOLD = 2
  ARROW_ANGLE = Math::PI / 6
  MIN_ARROW_SCALE = 0.3
  SCALE_DISTANCE_THRESHOLD = 120
  WIDTH_MULTIPLIER = 1.75

  attr_reader :start_point, :end_point

  # Holding shift while drawing snaps the arrow to the axis it travelled
  # furthest along.
  def initialize(start_point, end_point, shift, options)
    super()
    @options = options
    @start_point = start_point
    @end_point = constrain(start_point, end_point, shift)
  end

  def draw(context, image_to_widget_coords, scale)
    image_to_widget_coords.call(*@start_point).then do |(start_x, start_y)|
      image_to_widget_coords.call(*@end_point).then do |(end_x, end_y)|
        if Math.hypot(end_x - start_x, end_y - start_y) >= MIN_DISTANCE_THRESHOLD
          draw_arrow(
            context,
            [start_x, start_y],
            [end_x, end_y],
            scale,
          )
        end
      end
    end
  end

  def bounds
    distance.then do |length|
      if length < MIN_DISTANCE_THRESHOLD
        QuadBounds.from_rect(
          @start_point[0],
          @start_point[1],
          @start_point[0],
          @start_point[1],
        )
      else
        quad_around(head_size(length / SCALE_DISTANCE_THRESHOLD))
      end
    end
  end

  def translate(dx, dy)
    @start_point = [@start_point[0] + dx, @start_point[1] + dy]
    @end_point = [@end_point[0] + dx, @end_point[1] + dy]
  end

  # A click counts as hitting a line or arrow when it lands within the stroke's
  # own width of the segment, not merely inside its bounding box.
  def contains_point?(x_img, y_img)
    segment_distance_squared(x_img, y_img) < ((5 + (@options.size * WIDTH_MULTIPLIER))**2)
  end

  private

    def constrain(start_point, end_point, shift)
      if shift
        axis_aligned(start_point, end_point)
      else
        end_point
      end
    end

    def axis_aligned(start_point, end_point)
      if (end_point[0] - start_point[0]).abs > (end_point[1] - start_point[1]).abs
        [end_point[0], start_point[1]]
      else
        [start_point[0], end_point[1]]
      end
    end

    def distance = Math.hypot(@end_point[0] - @start_point[0], @end_point[1] - @start_point[1])

    def head_size(arrow_scale)
      (@options.size * ARROW_HEAD_SIZE_MULTIPLIER * WIDTH_MULTIPLIER) *
        [1.0, [MIN_ARROW_SCALE, arrow_scale].max].min
    end

    def draw_arrow(context, start_widget, end_widget, scale)
      context.line_width = @options.size * WIDTH_MULTIPLIER * scale
      context.line_cap = Cairo::LINE_CAP_ROUND
      set_color(context, @options.primary_color)

      segment(context, start_widget, end_widget)
      head(
        context,
        start_widget,
        end_widget,
        scale,
      )
    end

    def segment(context, from_point, to_point)
      context.move_to(*from_point)
      context.line_to(*to_point)
      context.stroke
    end

    def head(context, start_widget, end_widget, scale)
      Math.atan2(end_widget[1] - start_widget[1], end_widget[0] - start_widget[0]).then do |angle|
        head_length(start_widget, end_widget, scale).then do |length|
          [angle + Math::PI - ARROW_ANGLE, angle + Math::PI + ARROW_ANGLE].each do |barb_angle|
            segment(
              context,
              end_widget,
              [
                end_widget[0] + (length * Math.cos(barb_angle)),
                end_widget[1] + (length * Math.sin(barb_angle)),
              ],
            )
          end
        end
      end
    end

    # The head is sized from the on-screen length, so it keeps its proportions
    # as the overlay is zoomed.
    def head_length(start_widget, end_widget, scale)
      Math.hypot(end_widget[0] - start_widget[0], end_widget[1] - start_widget[1]).then do |widget_distance|
        head_size(widget_distance / (SCALE_DISTANCE_THRESHOLD * scale)) * scale
      end
    end

    # The quad is the segment widened by `extent` on both sides, perpendicular
    # to its own direction.
    def quad_around(extent)
      Math.atan2(@end_point[1] - @start_point[1], @end_point[0] - @start_point[0]).then do |angle|
        [-Math.sin(angle), Math.cos(angle)].then do |(perp_cos, perp_sin)|
          QuadBounds.new(
            [@start_point[0] + (extent * perp_cos), @start_point[1] + (extent * perp_sin)],
            [@end_point[0] + (extent * perp_cos), @end_point[1] + (extent * perp_sin)],
            [@end_point[0] - (extent * perp_cos), @end_point[1] - (extent * perp_sin)],
            [@start_point[0] - (extent * perp_cos), @start_point[1] - (extent * perp_sin)],
          )
        end
      end
    end

    def segment_distance_squared(px, py)
      @start_point.then do |(x1, y1)|
        @end_point.then do |(x2, y2)|
          (((x2 - x1)**2) + ((y2 - y1)**2)).to_f.then do |length_squared|
            if length_squared.zero?
              ((px - x1)**2) + ((py - y1)**2)
            else
              closest_distance_squared(px, py, length_squared)
            end
          end
        end
      end
    end

    def closest_distance_squared(px, py, length_squared)
      @start_point.then do |(x1, y1)|
        @end_point.then do |(x2, y2)|
          [0.0, [1.0, (((px - x1) * (x2 - x1)) + ((py - y1) * (y2 - y1))) / length_squared].min].max
            .then do |t|
              ((px - (x1 + (t * (x2 - x1))))**2) + ((py - (y1 + (t * (y2 - y1))))**2)
            end
        end
      end
    end
end

# LineAction is an ArrowAction without the head: the same shift-snapping and
# the same hit test, drawn as a single capped segment pulled in by half its own
# width at each end so the round caps do not overshoot the drawn length.
#
# Ported from gradia/overlay/drawing_actions.py (the LineAction class).
class LineAction < ArrowAction
  def draw(context, image_to_widget_coords, scale)
    image_to_widget_coords.call(*@start_point).then do |(start_x, start_y)|
      image_to_widget_coords.call(*@end_point).then do |(end_x, end_y)|
        draw_line(
          context,
          [start_x, start_y],
          [end_x, end_y],
          scale,
        )
      end
    end
  end

  def bounds = quad_around(@options.size * WIDTH_MULTIPLIER / 2)

  private

    def draw_line(context, start_widget, end_widget, scale)
      Math.atan2(end_widget[1] - start_widget[1], end_widget[0] - start_widget[0]).then do |angle|
        (@options.size * WIDTH_MULTIPLIER * scale / 2).then do |half_width|
          context.line_width = @options.size * WIDTH_MULTIPLIER * scale
          set_color(context, @options.primary_color)
          segment(
            context,
            inset(start_widget, angle, half_width),
            inset(end_widget, angle, -half_width),
          )
        end
      end
    end

    def inset(point, angle, amount)
      [point[0] + (amount * Math.cos(angle)), point[1] + (amount * Math.sin(angle))]
    end
end

# RectAction is a stroked, optionally filled rectangle. The stroke is drawn
# inside the dragged rectangle rather than centred on it, so the shape stays
# where it was dragged however thick the stroke is.
#
# Ported from gradia/overlay/drawing_actions.py (the RectAction class).
class RectAction < DrawingAction
  attr_reader :start_point, :end_point, :shift

  def initialize(start_point, end_point, shift, options)
    super()
    @options = options
    @start_point = start_point
    @end_point = end_point
    @shift = shift
  end

  def draw(context, image_to_widget_coords, scale)
    widget_rect(image_to_widget_coords, scale).then do |(x, y, width, height)|
      if width.positive? && height.positive?
        paint(
          context,
          x,
          y,
          width,
          height,
          scale,
        )
      end
    end
  end

  def bounds
    if @shift
      QuadBounds.from_start_end(@start_point, squared_end)
    else
      QuadBounds.from_start_end(@start_point, @end_point)
    end
  end

  def translate(dx, dy)
    @start_point = [@start_point[0] + dx, @start_point[1] + dy]
    @end_point = [@end_point[0] + dx, @end_point[1] + dy]
  end

  private

    def paint(context, x, y, width, height, scale)
      if visible_color?(@options.fill_color)
        set_color(context, @options.fill_color)
        context.rectangle(
          x,
          y,
          width,
          height,
        )
        context.fill
      end

      set_color(context, @options.primary_color)
      context.line_width = @options.size * scale
      context.rectangle(
        x,
        y,
        width,
        height,
      )
      context.stroke
    end

    # Shift squares the shape off the longer dragged side, keeping the corner
    # the drag started from.
    def squared_end
      [(@end_point[0] - @start_point[0]).abs, (@end_point[1] - @start_point[1]).abs].max.then do |size|
        [
          @start_point[0] + (size * direction(@end_point[0], @start_point[0])),
          @start_point[1] + (size * direction(@end_point[1], @start_point[1])),
        ]
      end
    end

    def direction(value, origin)
      if value < origin
        -1
      else
        1
      end
    end

    def widget_corners(image_to_widget_coords)
      image_to_widget_coords.call(*@start_point).then do |first|
        image_to_widget_coords.call(*@end_point).then do |second|
          if @shift
            [first, squared_widget_end(first, second)]
          else
            [first, second]
          end
        end
      end
    end

    def squared_widget_end(first, second)
      [(second[0] - first[0]).abs, (second[1] - first[1]).abs].max.then do |size|
        [
          first[0] + (size * direction(second[0], first[0])),
          first[1] + (size * direction(second[1], first[1])),
        ]
      end
    end

    def widget_rect(image_to_widget_coords, scale)
      widget_corners(image_to_widget_coords).then do |(first, second)|
        (@options.size * scale / 2).then do |stroke_offset|
          [
            [first[0], second[0]].min + stroke_offset,
            [first[1], second[1]].min + stroke_offset,
            (second[0] - first[0]).abs - (@options.size * scale),
            (second[1] - first[1]).abs - (@options.size * scale),
          ]
        end
      end
    end
end

# CircleAction is RectAction's ellipse: the same drag, shift-squaring and
# bounds, inscribed in the dragged rectangle.
#
# Ported from gradia/overlay/drawing_actions.py (the CircleAction class).
class CircleAction < RectAction
  def draw(context, image_to_widget_coords, scale)
    widget_ellipse(image_to_widget_coords, scale).then do |(cx, cy, rx, ry)|
      if rx.positive? && ry.positive?
        paint_ellipse(
          context,
          [cx, cy],
          [rx, ry],
          scale,
        )
      end
    end
  end

  private

    def widget_ellipse(image_to_widget_coords, scale)
      widget_corners(image_to_widget_coords).then do |(first, second)|
        [
          (first[0] + second[0]) / 2.0,
          (first[1] + second[1]) / 2.0,
          ((second[0] - first[0]).abs - (@options.size * scale)) / 2.0,
          ((second[1] - first[1]).abs - (@options.size * scale)) / 2.0,
        ]
      end
    end

    # A unit circle under a non-uniform scale is the ellipse; the scale is
    # undone before stroking so the outline keeps an even width.
    def paint_ellipse(context, center, radii, scale)
      context.save
      context.translate(*center)
      context.scale(*radii)
      context.arc(
        0,
        0,
        1,
        0,
        2 * Math::PI,
      )
      context.restore

      if visible_color?(@options.fill_color)
        set_color(context, @options.fill_color)
        context.fill_preserve
      end

      set_color(context, @options.primary_color)
      context.line_width = @options.size * scale
      context.stroke
    end
end

# HighlighterAction is a translucent marker stroke, multiplied into the image
# so overlapping passes darken the way a real highlighter does. Shift keeps it
# to a single horizontal sweep.
#
# Ported from gradia/overlay/drawing_actions.py (the HighlighterAction class).
class HighlighterAction < StrokeAction
  def initialize(stroke, options, shift)
    super(constrain(stroke, shift), options)
  end

  def draw(context, image_to_widget_coords, scale)
    if @stroke.length >= 2
      highlight(context, @stroke.map { |(x, y)| image_to_widget_coords.call(x, y) }, scale)
    end
  end

  def bounds = bounds_from_stroke(@options.size + 3)

  private

    def constrain(stroke, shift)
      if shift && stroke.length >= 2
        [stroke.first, [stroke.last[0], stroke.first[1]]]
      else
        stroke
      end
    end

    def highlight(context, coords, scale)
      context.operator = Cairo::OPERATOR_MULTIPLY
      set_color(context, @options.primary_color)
      context.line_width = @options.size * scale * 2
      context.line_cap = Cairo::LINE_CAP_BUTT
      context.move_to(*coords.first)
      coords.drop(1).each { |point| context.line_to(*point) }
      context.stroke
      context.operator = Cairo::OPERATOR_OVER
      context.line_cap = Cairo::LINE_CAP_ROUND
    end
end

# CensorAction pixelates the region it covers, by sampling the image it was
# drawn over down to one pixel per block and scaling that back up with nearest
# neighbour.
#
# Ported from gradia/overlay/drawing_actions.py (the CensorAction class).
class CensorAction < RectAction
  BASE_BLOCK_SIZE = 8

  attr_reader :background_pixbuf, :original_scale

  def initialize(start_point, end_point, background_pixbuf, options)
    super(
      start_point,
end_point,
false,
options
)
    @background_pixbuf = background_pixbuf
    @original_scale = 1.0
  end

  # The blocks are sized against the zoom the censor was drawn at, so zooming
  # in shows bigger blocks rather than finer ones.
  def original_scale=(scale)
    @original_scale = scale
  end

  def draw(context, image_to_widget_coords, scale)
    image_crop.then do |crop|
      if crop
        draw_crop(
          context,
          crop,
          image_to_widget_coords,
          scale,
        )
      end
    end
  end

  def bounds = QuadBounds.from_start_end(@start_point, @end_point)

  private

    def scaled_block_size(current_scale) = BASE_BLOCK_SIZE * (current_scale / @original_scale)

    # The action's coordinates are centred on the image, while the crop is in
    # pixbuf pixels from its top-left corner.
    def image_crop
      @background_pixbuf.then do |pixbuf|
        clamp_crop(
          [
            (@start_point[0] + (pixbuf.width / 2.0)).to_i,
            (@start_point[1] + (pixbuf.height / 2.0)).to_i,
          ],
          [
            (@end_point[0] + (pixbuf.width / 2.0)).to_i,
            (@end_point[1] + (pixbuf.height / 2.0)).to_i,
          ],
        )
      end
    end

    def clamp_crop(first, second)
      [first[0], second[0]].map { |x| x.clamp(0, @background_pixbuf.width) }.sort.then do |(x_start, x_end)|
        [first[1], second[1]].map { |y| y.clamp(0, @background_pixbuf.height) }.sort.then do |(y_start, y_end)|
          crop_hash(
            x_start,
            y_start,
            x_end - x_start,
            y_end - y_start,
          )
        end
      end
    end

    def crop_hash(x, y, width, height)
      if width.positive? && height.positive?
        { x: x, y: y, width: width, height: height }
      end
    end

    def draw_crop(context, crop, image_to_widget_coords, scale)
      widget_box(crop, image_to_widget_coords).then do |(x, y, width, height)|
        if width >= 1 && height >= 1
          draw_pixelation(
            context,
            crop,
            [x, y],
            [width, height],
            scaled_block_size(scale),
          )
        end
      end
    end

    def widget_box(crop, image_to_widget_coords)
      (crop[:x] - (@background_pixbuf.width / 2.0)).then do |crop_x|
        (crop[:y] - (@background_pixbuf.height / 2.0)).then do |crop_y|
          image_to_widget_coords.call(crop_x.to_i, crop_y.to_i).then do |(x1, y1)|
            image_to_widget_coords.call((crop_x + crop[:width]).to_i, (crop_y + crop[:height]).to_i)
              .then { |(x2, y2)| [[x1, x2].min, [y1, y2].min, (x2 - x1).abs, (y2 - y1).abs] }
          end
        end
      end
    end

    def draw_pixelation(context, crop, origin, size, block_size)
      blocks(size, block_size).then do |(blocks_x, blocks_y)|
        context.save
        context.rectangle(
          origin[0],
          origin[1],
          size[0],
          size[1],
        )
        context.clip
        paint_blocks(
          context,
          tiny_surface(crop, blocks_x, blocks_y),
          origin,
          size,
          [blocks_x, blocks_y],
        )
        context.restore
      end
    end

    def blocks(size, block_size)
      [[1, (size[0] / block_size).to_i].max, [1, (size[1] / block_size).to_i].max]
    end

    # One pixel per block: the crop is drawn into a surface that small, which
    # makes Cairo's own downscaling do the averaging.
    def tiny_surface(crop, blocks_x, blocks_y)
      Cairo::ImageSurface.new(Cairo::FORMAT_ARGB32, blocks_x, blocks_y).tap do |surface|
        Cairo::Context.new(surface).tap do |tiny|
          tiny.scale(blocks_x.to_f / crop[:width], blocks_y.to_f / crop[:height])
          tiny.translate(-crop[:x], -crop[:y])
          tiny.set_source_pixbuf(@background_pixbuf, 0, 0)
          tiny.paint
        end
      end
    end

    def paint_blocks(context, surface, origin, size, block_counts)
      context.translate(*origin)
      context.scale(size[0].to_f / block_counts[0], size[1].to_f / block_counts[1])
      context.set_source(Cairo::SurfacePattern.new(surface).tap { |pattern| pattern.filter = Cairo::FILTER_NEAREST })
      context.paint
    end
end

# NumberStampAction is a filled, optionally outlined circle with a number in
# it, for the numbered callouts.
#
# Ported from gradia/overlay/drawing_actions.py (the NumberStampAction class).
class NumberStampAction < DrawingAction
  FONT_FAMILY = 'Adwaita Sans'
  RADIUS_MULTIPLIER = 2

  attr_reader :position, :number, :creation_time

  def initialize(position, number, options)
    super()
    @options = options
    @position = position
    @number = number
    @creation_time = Time.now.to_f
  end

  def draw(context, image_to_widget_coords, scale)
    image_to_widget_coords.call(*@position).then do |(x, y)|
      (@options.size * RADIUS_MULTIPLIER * scale).then do |radius|
        disc(
          context,
          [x, y],
          radius,
          scale,
        )
        numeral(
          context,
          [x, y],
          radius,
          scale,
        )
      end
    end
  end

  # Circles are hit-tested as circles, with the same few pixels of slack the
  # other tools get.
  def contains_point?(px_img, py_img)
    (((px_img - @position[0])**2) + ((py_img - @position[1])**2)) <=
      (((@options.size * RADIUS_MULTIPLIER) + 5)**2)
  end

  def bounds
    total_radius.then do |radius|
      QuadBounds.from_rect(
        @position[0] - radius,
        @position[1] - radius,
        @position[0] + radius,
        @position[1] + radius,
      )
    end
  end

  def translate(dx, dy)
    @position = [@position[0] + dx, @position[1] + dy]
  end

  private

    def total_radius
      (@options.size * RADIUS_MULTIPLIER) + outline_padding + 1
    end

    def outline_padding
      if visible_color?(@options.border_color)
        2
      else
        0
      end
    end

    # The ring is only stroked when both the fill and the border are visible;
    # otherwise upstream drops the path so a transparent fill does not leave a
    # stray outline behind.
    def disc(context, center, radius, scale)
      set_color(context, @options.fill_color)
      context.arc(
        center[0],
        center[1],
        radius,
        0,
        2 * Math::PI,
      )
      context.fill_preserve

      if ring?
        set_color(context, @options.border_color)
        context.line_width = 2.0 * scale
        context.stroke
      else
        context.new_path
      end
    end

    def ring?
      Colors.components(@options.border_color).last.positive? &&
        Colors.components(@options.fill_color).last.positive?
    end

    def numeral(context, center, radius, scale)
      context.select_font_face(FONT_FAMILY, Cairo::FONT_SLANT_NORMAL, Cairo::FONT_WEIGHT_BOLD)
      context.font_size = radius * 1.2

      context.text_extents(@number.to_s).then do |extents|
        context.move_to(
          center[0] - (extents.width / 2) - extents.x_bearing,
          center[1] + (extents.height / 2),
        )
        context.text_path(@number.to_s)
        outline_and_fill(context, scale)
      end
    end

    def outline_and_fill(context, scale)
      if visible_color?(@options.border_color)
        set_color(context, @options.border_color)
        context.line_width = 4 * scale
        context.stroke_preserve
      end

      set_color(context, @options.primary_color)
      context.fill
    end
end

# TextAction is a centred, multi-line text annotation: an optional rounded
# background behind each line, then the glyphs, outlined in the border colour
# when one is set.
#
# Ported from gradia/overlay/drawing_actions.py (the TextAction class).
class TextAction < DrawingAction
  PADDING_X_IMG = 4
  PADDING_Y_IMG = 2
  BASE_OUTLINE_WIDTH = 2.0
  REFERENCE_FONT_SIZE = 14.0

  attr_reader :position, :text, :intrinsic_image_bounds, :font_size

  def initialize(position, text, intrinsic_image_bounds, options, font_size)
    super()
    @options = options
    @position = position
    @text = text
    @intrinsic_image_bounds = intrinsic_image_bounds
    @font_size = font_size
  end

  # Emoji and other pictographic glyphs are drawn as glyphs rather than as a
  # path, because a colour font has no outline to fill.
  def emoji?
    @text.each_char.any? do |char|
      char.ord > 0xFFFF || %w[So Sk Sm Sc].include?(char_category(char))
    end
  end

  def draw(context, image_to_widget_coords, scale)
    unless @text.strip.empty?
      draw_text(context, image_to_widget_coords.call(*@position), scale)
    end
  end

  def bounds
    if @text.strip.empty?
      QuadBounds.from_rect(
        @position[0],
        @position[1],
        @position[0],
        @position[1],
      )
    else
      text_bounds
    end
  end

  def translate(dx, dy)
    @position = [@position[0] + dx, @position[1] + dy]
  end

  private

    # Ruby has no Unicode category lookup in core, so the few general
    # categories upstream tests for are recognised by regexp instead.
    def char_category(char)
      case char
      when /\p{So}/ then 'So'
      when /\p{Sk}/ then 'Sk'
      when /\p{Sm}/ then 'Sm'
      when /\p{Sc}/ then 'Sc'
      end
    end

    def layout_for(context, text, scale)
      context.create_pango_layout.tap do |layout|
        layout.font_description = font_description(scale)
        layout.text = text
        layout.alignment = :center
      end
    end

    def font_description(scale)
      Pango::FontDescription.new.tap do |description|
        description.family = @options.font
        description.size = (@font_size * scale * Pango::SCALE).to_i
      end
    end

    def logical_size(layout)
      layout.extents.last.then do |logical|
        [logical.width.to_f / Pango::SCALE, logical.height.to_f / Pango::SCALE]
      end
    end

    def draw_text(context, widget_position, scale)
      layout_for(context, @text, scale).then do |layout|
        logical_size(layout).then do |(text_width, text_height)|
          [widget_position[0] - (text_width / 2), widget_position[1] - text_height].then do |origin|
            background(
              context,
              layout,
              origin,
              scale,
            )
            glyphs(
              context,
              layout,
              origin,
              scale,
            )
          end
        end
      end
    end

    def background(context, layout, origin, scale)
      if visible_color?(@options.fill_color)
        set_color(context, @options.fill_color)
        draw_per_line_background(
          context,
          layout,
          origin,
          scale,
        )
      end
    end

    def glyphs(context, layout, origin, scale)
      context.move_to(*origin)

      if emoji?
        set_color(context, @options.primary_color)
        context.show_pango_layout(layout)
      else
        context.pango_layout_path(layout)
        outline(context, scale)
        set_color(context, @options.primary_color)
        context.fill
      end
    end

    def outline(context, scale)
      if visible_color?(@options.border_color)
        set_color(context, @options.border_color)
        context.line_width = BASE_OUTLINE_WIDTH * scale * (@font_size / REFERENCE_FONT_SIZE)
        context.stroke_preserve
      end
    end

    # A single line gets one rounded box; several get one per line, with the
    # corners between two lines of similar width left square so the stack of
    # boxes reads as one shape.
    def draw_per_line_background(context, layout, origin, scale)
      @text.split("\n").then do |lines|
        if lines.length <= 1
          single_line_background(
            context,
            layout,
            origin,
            scale,
          )
        else
          multi_line_background(
            context,
            layout,
            lines,
            origin,
            scale,
          )
        end
      end
    end

    def single_line_background(context, layout, origin, scale)
      logical_size(layout).then do |(text_width, text_height)|
        box(
          context,
          [origin[0] - (PADDING_X_IMG * scale), origin[1] - (PADDING_Y_IMG * scale)],
          [text_width + (2 * PADDING_X_IMG * scale), text_height + (2 * PADDING_Y_IMG * scale)],
          round_top:    true,
          round_bottom: true,
        )
        context.fill
      end
    end

    def multi_line_background(context, layout, lines, origin, scale)
      line_sizes(context, lines, scale).then do |sizes|
        logical_size(layout).first.then do |overall_width|
          sizes.each_with_index.inject(origin[1]) do |current_y, ((line_width, line_height), index)|
            line_box(
              context,
              [
                origin[0] + ((overall_width - line_width) / 2) - (PADDING_X_IMG * scale),
                current_y - (PADDING_Y_IMG * scale),
              ],
              [
                line_width + (2 * PADDING_X_IMG * scale),
                line_height + (2 * PADDING_Y_IMG * scale),
              ],
              corners(sizes, index),
            )
            current_y + line_height
          end
        end
      end
    end

    def line_sizes(context, lines, scale)
      lines.map { |line| logical_size(layout_for(context, line, scale)) }
    end

    # A corner is left square when the neighbouring line is at least as wide,
    # so the boxes of a wider line and the line under it merge.
    def corners(sizes, index)
      {
        round_top:    !(index.positive? && sizes[index - 1].first >= sizes[index].first),
        round_bottom: !(index < sizes.length - 1 && sizes[index + 1].first >= sizes[index].first),
      }
    end

    def line_box(context, origin, size, rounding)
      box(
        context,
        origin,
        size,
        round_top:    rounding[:round_top],
        round_bottom: rounding[:round_bottom],
      )
      context.fill
    end

    def box(context, origin, size, round_top:, round_bottom:)
      [6.0, size.min / 4].min.then do |radius|
        rounded_rectangle(
          context,
          origin,
          size,
          radius,
          round_top:    round_top,
          round_bottom: round_bottom,
        )
      end
    end

    def rounded_rectangle(context, origin, size, radius, round_top:, round_bottom:)
      context.new_sub_path
      top_edge(
        context,
        origin,
        size,
        radius,
        round_top,
      )
      bottom_edge(
        context,
        origin,
        size,
        radius,
        round_bottom,
      )
      context.close_path
    end

    def top_edge(context, origin, size, radius, rounded)
      if rounded
        context.arc(
          origin[0] + radius,
          origin[1] + radius,
          radius,
          Math::PI,
          3 * Math::PI / 2,
        )
        context.arc(
          origin[0] + size[0] - radius,
          origin[1] + radius,
          radius,
          3 * Math::PI / 2,
          0,
        )
      else
        context.move_to(origin[0], origin[1])
        context.line_to(origin[0] + size[0], origin[1])
      end
    end

    def bottom_edge(context, origin, size, radius, rounded)
      if rounded
        context.arc(
          origin[0] + size[0] - radius,
          origin[1] + size[1] - radius,
          radius,
          0,
          Math::PI / 2,
        )
        context.arc(
          origin[0] + radius,
          origin[1] + size[1] - radius,
          radius,
          Math::PI / 2,
          Math::PI,
        )
      else
        context.line_to(origin[0] + size[0], origin[1] + size[1])
        context.line_to(origin[0], origin[1] + size[1])
      end
    end

    # Measured at scale 1, because bounds are in image coordinates.
    def text_bounds
      Cairo::Context.new(Cairo::ImageSurface.new(Cairo::FORMAT_ARGB32, 1, 1)).then do |context|
        logical_size(layout_for(context, @text, 1.0)).then do |(text_width, text_height)|
          quad_for(text_width.to_i, text_height.to_i)
        end
      end
    end

    def quad_for(text_width, text_height)
      bounds_outline_padding.then do |padding|
        QuadBounds.from_rect(
          @position[0] - (text_width / 2) - PADDING_X_IMG - padding,
          @position[1] - text_height - PADDING_Y_IMG - padding,
          @position[0] + (text_width / 2) + PADDING_X_IMG + padding,
          @position[1] + PADDING_Y_IMG + padding,
        )
      end
    end

    def bounds_outline_padding
      if visible_color?(@options.border_color)
        (BASE_OUTLINE_WIDTH * (@font_size / REFERENCE_FONT_SIZE)).to_i + 1
      else
        0
      end
    end
end
