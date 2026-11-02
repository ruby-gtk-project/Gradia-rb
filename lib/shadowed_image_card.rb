# frozen_string_literal: true

require 'adwaita'
require_relative 'logger'

# ShadowedImageCard is one thumbnail on the welcome page: the image centred in
# its padding, rounded off at the corners and lifted off the gradient behind it
# by a soft shadow.
#
# Ported from gradia/ui/recent_picker.py (the ShadowedImageCard class).
# Upstream paints in `do_snapshot` with three stacked Gsk.Shadow nodes; the
# Ruby bindings cannot override a widget's snapshot and Cairo has no blur, so
# the card draws into a Gtk::DrawingArea and the blur is built up from
# concentric rounded rectangles whose alpha falls off over the same 24 pixels
# upstream's widest shadow spans.
class ShadowedImageCard
  FULL_SIZE = [260, 160].freeze
  COMPACT_SIZE = [155, 120].freeze

  SHADOW_SPREAD = 24
  SHADOW_ALPHA = 0.32
  SHADOW_STEPS = 24

  attr_reader :path, :radius, :padding, :pixbuf, :load_error

  def initialize(path, radius: 4.0, padding: 8, compact: false)
    @path = path
    @radius = radius
    @padding = padding
    @compact = compact
    load_pixbuf
  end

  def build
    drawing_area.tap do |area|
      area.set_draw_func { |_widget, context, width, height| draw(context, width, height) }
    end
  end

  def loaded? = !@pixbuf.nil?

  def size
    if @compact
      COMPACT_SIZE
    else
      FULL_SIZE
    end
  end

  def drawing_area
    @drawing_area ||= Gtk::DrawingArea.new.tap do |area|
      area.set_size_request(*size)
      area.hexpand = true
      area.vexpand = true
    end
  end

  private

    # Scaled on load, as upstream does with new_from_file_at_size, so a 4K
    # screenshot does not sit in memory at full size for a 260px card.
    def load_pixbuf
      @pixbuf = GdkPixbuf::Pixbuf.new(file: @path, width: size[0], height: size[1], preserve_aspect_ratio: true)
    rescue StandardError => error
      @pixbuf = nil
      @load_error = error.message
      GradiaLogger.new.warning("Failed to load image #{@path}", exception: error, show_exception: true)
    end

    def draw(context, width, height)
      if @pixbuf
        image_rect(width, height).then do |rect|
          draw_shadow(context, rect)
          draw_image(context, rect)
        end
      end
    end

    # Fit inside the padding, centred — the scale is the smaller of the two
    # axes' ratios so the whole image stays visible.
    def image_rect(width, height)
      [width - (@padding * 2), height - (@padding * 2)].then do |(available_width, available_height)|
        [available_width.to_f / @pixbuf.width, available_height.to_f / @pixbuf.height].min.then do |scale|
          [@pixbuf.width * scale, @pixbuf.height * scale].then do |(scaled_width, scaled_height)|
            [
              @padding + ((available_width - scaled_width) / 2),
              @padding + ((available_height - scaled_height) / 2),
              scaled_width,
              scaled_height,
            ]
          end
        end
      end
    end

    def draw_shadow(context, rect)
      SHADOW_STEPS.times do |step|
        ((step + 1).to_f / SHADOW_STEPS).then do |t|
          context.set_source_rgba(
            0,
            0,
            0,
            SHADOW_ALPHA * ((1 - t)**2) / SHADOW_STEPS,
          )
          rounded_rectangle(context, inflate(rect, SHADOW_SPREAD * t), @radius + (SHADOW_SPREAD * t))
          context.fill
        end
      end
    end

    def inflate(rect, amount)
      [rect[0] - amount, rect[1] - amount, rect[2] + (amount * 2), rect[3] + (amount * 2)]
    end

    def draw_image(context, rect)
      context.save
      rounded_rectangle(context, rect, @radius)
      context.clip
      context.translate(rect[0], rect[1])
      context.scale(rect[2] / @pixbuf.width, rect[3] / @pixbuf.height)
      context.set_source_pixbuf(@pixbuf, 0, 0)
      context.paint
      context.restore
    end

    def rounded_rectangle(context, rect, radius)
      [radius, rect[2] / 2, rect[3] / 2].min.then do |r|
        context.new_sub_path
        context.arc(
          rect[0] + rect[2] - r,
          rect[1] + r,
          r,
          -Math::PI / 2,
          0,
        )
        context.arc(
          rect[0] + rect[2] - r,
          rect[1] + rect[3] - r,
          r,
          0,
          Math::PI / 2,
        )
        context.arc(
          rect[0] + r,
          rect[1] + rect[3] - r,
          r,
          Math::PI / 2,
          Math::PI,
        )
        context.arc(
          rect[0] + r,
          rect[1] + r,
          r,
          Math::PI,
          3 * Math::PI / 2,
        )
        context.close_path
      end
    end
end
