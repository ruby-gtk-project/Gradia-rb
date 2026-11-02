# frozen_string_literal: true

require 'adwaita'

# TransparencyBackground is the chequerboard that shows through the
# transparent parts of the picture on the canvas. It sits under the
# Gtk::Picture and is drawn only over the area the picture's image actually
# covers, so the squares line up with the image rather than the widget.
#
# Ported from gradia/overlay/transparency_overlay.py. Upstream subclasses
# Gtk.Widget and paints in `do_snapshot` with Gsk colour nodes and a repeat
# node; the Ruby bindings cannot override a widget's snapshot, so the same
# geometry is drawn with Cairo into a Gtk::DrawingArea, and the repeat node
# becomes a pair of nested loops.
class TransparencyBackground
  SQUARE_SIZE = 10
  MAX_TILES_X = 20
  MAX_TILES_Y = 20
  INSET = 2

  LIGHT_GRAY = [0.9, 0.9, 0.9].freeze
  DARK_GRAY = [0.7, 0.7, 0.7].freeze

  def initialize(picture: nil)
    @picture = picture
  end

  def build
    drawing_area.tap do |area|
      area.set_draw_func { |_widget, context, width, height| draw(context, width, height) }
    end
  end

  def picture = @picture

  # The chequerboard follows the picture's image, so it has to be redrawn
  # whenever that image changes.
  def picture=(widget)
    @picture = widget

    if widget
      widget.signal_connect('notify::paintable') { drawing_area.queue_draw }
    end
  end

  def drawing_area = @drawing_area ||= Gtk::DrawingArea.new

  private

    def draw(context, width, height)
      geometry(width, height).then do |(offset_x, offset_y, display_width, display_height, square_size)|
        if display_width.positive? && display_height.positive?
          fill_light(
            context,
            offset_x,
            offset_y,
            [display_width, display_height],
          )
          fill_dark(
            context,
            [offset_x, offset_y],
            [display_width, display_height],
            square_size,
          )
        end
      end
    end

    def fill_light(context, offset_x, offset_y, size)
      context.set_source_rgb(*LIGHT_GRAY)
      context.rectangle(
        offset_x,
        offset_y,
        size.first,
        size.last,
      )
      context.fill
    end

    # The dark squares of a chequerboard: the second square of the first row
    # and the first of the second, repeated over the whole area and clipped to
    # it.
    def fill_dark(context, origin, size, square_size)
      if square_size.positive?
        context.save
        context.rectangle(
          origin.first,
          origin.last,
          size.first,
          size.last,
        )
        context.clip
        context.set_source_rgb(*DARK_GRAY)
        tile(
          context,
          origin,
          size,
          square_size,
        )
        context.restore
      end
    end

    def tile(context, origin, size, square_size)
      (2 * square_size).then do |tile_size|
        (size.last / tile_size).ceil.succ.times do |row|
          (size.first / tile_size).ceil.succ.times do |column|
            dark_squares(
              context,
              [origin.first + (column * tile_size), origin.last + (row * tile_size)],
              square_size,
            )
          end
        end
      end

      context.fill
    end

    def dark_squares(context, corner, square_size)
      context.rectangle(
        corner.first + square_size,
        corner.last,
        square_size,
        square_size,
      )
      context.rectangle(
        corner.first,
        corner.last + square_size,
        square_size,
        square_size,
      )
    end

    # offset, size and the side of one square. The square grows with the
    # picture's zoom so the board stays put relative to the image, but never
    # below a twentieth of the area, so a tiny image does not turn into a
    # thousand squares.
    def geometry(width, height)
      image_bounds(width, height).then do |(offset_x, offset_y, display_width, display_height)|
        scale(display_width, display_height).then do |factor|
          if factor.positive?
            [
              offset_x,
              offset_y,
              display_width,
              display_height,
              [SQUARE_SIZE * factor, display_width / MAX_TILES_X, display_height / MAX_TILES_Y].max,
            ]
          else
            [offset_x, offset_y, display_width, display_height, 0]
          end
        end
      end
    end

    def scale(display_width, display_height)
      intrinsic_size.then do |(image_width, image_height)|
        if image_width&.positive? && image_height&.positive?
          [display_width / image_width, display_height / image_height].min
        else
          1.0
        end
      end
    end

    # The rectangle the picture's image occupies inside the picture widget:
    # the image is scaled to fit and centred, which is what `contain` does.
    def image_bounds(width, height)
      intrinsic_size.then do |(image_width, image_height)|
        if @picture && image_width&.positive? && image_height&.positive?
          fitted_bounds(image_width, image_height)
        else
          [INSET, INSET, width - (2 * INSET), height - (2 * INSET)]
        end
      end
    end

    def fitted_bounds(image_width, image_height)
      [@picture.width.to_f / image_width, @picture.height.to_f / image_height].min.then do |factor|
        [image_width * factor, image_height * factor].then do |(display_width, display_height)|
          [
            ((@picture.width - display_width) / 2) + INSET,
            ((@picture.height - display_height) / 2) + INSET,
            display_width - (2 * INSET),
            display_height - (2 * INSET),
          ]
        end
      end
    end

    def intrinsic_size
      @picture&.paintable.then do |paintable|
        if paintable
          [paintable.intrinsic_width, paintable.intrinsic_height]
        else
          [nil, nil]
        end
      end
    end
end
