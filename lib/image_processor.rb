# frozen_string_literal: true

require 'adwaita'

# ImageProcessor composites one edited screenshot: it rotates and auto-pads
# the source image, crops it when the padding option goes negative, rounds its
# corners, drops it onto the configured background at the padding and aspect
# ratio the sidebar chose, and lifts it off that background with a soft
# shadow.
#
# Ported from gradia/graphics/image_processor.py. Upstream holds pixels as PIL
# images and blurs the shadow with `ImageFilter.GaussianBlur`; this port holds
# them as `Cairo::ImageSurface` (ARGB32, premultiplied) the way every other
# graphics class in this port does, and — because Cairo has no blur, the same
# constraint lib/shadowed_image_card.rb documents — fakes the blur with
# concentric rounded rectangles whose alpha falls off toward the edge, instead
# of upstream's `GaussianBlur`.
class ImageProcessor
  SHADOW_OFFSET = [10, 10].freeze
  SHADOW_STEPS = 16

  attr_accessor :background, :padding, :aspect_ratio, :corner_radius, :shadow_strength, :auto_balance, :rotation

  def initialize(
    image: nil,
    background: nil,
    padding: 0,
    aspect_ratio: nil,
    corner_radius: 0,
    shadow_strength: 0,
    auto_balance: false,
    rotation: 0
  )
    @background = background
    @padding = padding
    @aspect_ratio = aspect_ratio
    @corner_radius = corner_radius
    @shadow_strength = shadow_strength
    @auto_balance = auto_balance
    @rotation = rotation
    @loaded_image = nil

    if image
      set_image(image)
    end
  end

  def set_image(image)
    unless image.loaded?
      raise ArgumentError, "Failed to load image: #{image.load_error}"
    end

    @loaded_image = image
  end

  # Renders the preview-resolution image and hands back the pixbuf plus the
  # dimensions the same composition would have at full resolution, which is
  # what the export flow asks for before it decides whether to redo the work
  # at `process_full_resolution`.
  def process
    unless @loaded_image&.preview_image
      raise 'No image loaded to process'
    end

    final_surface = render(@loaded_image.preview_image, scale: 1.0, balanced_padding: @loaded_image.balanced_padding)
    final_pixbuf = surface_to_pixbuf(final_surface)
    full_width, full_height = full_resolution_dimensions(final_pixbuf)
    [final_pixbuf, full_width, full_height]
  end

  def process_full_resolution
    unless @loaded_image&.full_res_image
      raise 'No full resolution image loaded to process'
    end

    surface_to_pixbuf(render(@loaded_image.full_res_image, scale: full_res_scale, balanced_padding: full_res_balanced_padding))
  end

  private

    def full_res_scale
      preview = @loaded_image.preview_image
      full = @loaded_image.full_res_image
      [full.width.to_f / preview.width, full.height.to_f / preview.height].max
    end

    def full_res_balanced_padding
      padding = @loaded_image.balanced_padding
      if @auto_balance && padding
        scale = full_res_scale
        BalancedPadding.new(
          top:    (padding.top * scale).to_i,
          bottom: (padding.bottom * scale).to_i,
          left:   (padding.left * scale).to_i,
          right:  (padding.right * scale).to_i,
          color:  padding.color,
        )
      else
        padding
      end
    end

    # The shared pipeline `process` and `process_full_resolution` both run,
    # over whichever pixbuf (preview or full resolution) the caller passes in.
    def render(source_pixbuf, scale:, balanced_padding:)
      pixbuf_to_surface(apply_rotation(source_pixbuf)).then do |source|
        if @auto_balance && balanced_padding
          source = apply_auto_balance(source, balanced_padding)
        end
        if @padding < 0
          source = crop(source)
        end
        if @corner_radius > 0
          source = apply_rounded_corners(source)
        end

        padded_width, padded_height = final_dimensions(source.width, source.height)
        final_surface = create_background(padded_width, padded_height)
        paste_x, paste_y = paste_position(
          source.width,
          source.height,
          padded_width,
          padded_height,
        )

        shadow, (shadow_x, shadow_y) = shadow_surface(source.width, source.height, scale)
        if shadow
          composite!(
            final_surface,
            shadow,
            paste_x - shadow_x,
            paste_y - shadow_y,
          )
        end
        composite!(
          final_surface,
          source,
          paste_x,
          paste_y,
        )

        final_surface
      end
    end

    def apply_rotation(pixbuf)
      case @rotation
      when 90 then pixbuf.rotate_simple(:counterclockwise)
      when 180 then pixbuf.rotate_simple(:upsidedown)
      when 270 then pixbuf.rotate_simple(:clockwise)
      else pixbuf
      end
    end

    def apply_auto_balance(surface, padding)
      new_width = surface.width + padding.left + padding.right
      new_height = surface.height + padding.top + padding.bottom

      blank_surface(new_width, new_height).tap do |balanced|
        Cairo::Context.new(balanced).tap do |context|
          fill_color(context, padding.color)
          context.paint
        end
        composite!(
          balanced,
          surface,
          padding.left,
          padding.top,
        )
      end
    end

    def crop(surface)
      smaller_dimension = [surface.width, surface.height].min
      padding_pixels = (percentage(@padding.abs) * smaller_dimension).to_i

      crop_width = [1, surface.width - (2 * padding_pixels)].max
      crop_height = [1, surface.height - (2 * padding_pixels)].max
      offset_x = (surface.width - crop_width) / 2
      offset_y = (surface.height - crop_height) / 2

      blank_surface(crop_width, crop_height).tap do |cropped|
        composite!(
          cropped,
          surface,
          -offset_x,
          -offset_y,
        )
      end
    end

    def apply_rounded_corners(surface)
      radius_pixels = corner_radius_pixels(surface.width, surface.height)

      blank_surface(surface.width, surface.height).tap do |rounded|
        Cairo::Context.new(rounded).tap do |context|
          rounded_rectangle(context, [0, 0, surface.width, surface.height], radius_pixels)
          context.clip
          context.set_source(surface, 0, 0)
          context.paint
        end
      end
    end

    def corner_radius_pixels(width, height)
      (percentage(@corner_radius) * [width, height].min).to_i
    end

    def percentage(value) = value / 100.0

    def final_dimensions(width, height)
      width = [1, width].max
      height = [1, height].max

      if @padding >= 0
        smaller_dimension = [width, height].min
        padding_pixels = (percentage(@padding) * smaller_dimension).to_i
        width += padding_pixels * 2
        height += padding_pixels * 2
      end

      if @aspect_ratio
        width, height = adjust_for_aspect_ratio(width, height)
      end

      [width, height]
    end

    def adjust_for_aspect_ratio(width, height)
      ratio = parse_aspect_ratio
      current = width.to_f / height

      if current < ratio
        width = (height * ratio).to_i
      elsif current > ratio
        height = (width / ratio).to_i
      end

      [width, height]
    rescue StandardError
      [width, height]
    end

    def parse_aspect_ratio
      if @aspect_ratio.is_a?(String) && @aspect_ratio.include?(':')
        w, h = @aspect_ratio.split(':').map(&:to_f)
        w / h
      elsif @aspect_ratio
        @aspect_ratio.to_f
      else
        raise ArgumentError, 'aspect_ratio is nil and cannot be converted to a float'
      end
    end

    def create_background(width, height)
      if @background
        @background.prepare_image(width, height)
      else
        blank_surface(width, height)
      end
    end

    def paste_position(image_width, image_height, background_width, background_height)
      if @padding >= 0
        [(background_width - image_width) / 2, (background_height - image_height) / 2]
      else
        [0, 0]
      end
    end

    # A faked Gaussian blur, built the way lib/shadowed_image_card.rb builds
    # its shadow: concentric rounded rectangles, each a little larger and a
    # little more transparent than the last, standing in for the blur radius
    # upstream computes from `shadow_strength`.
    def shadow_surface(image_width, image_height, scale)
      strength = [0.0, [@shadow_strength, 10].min].max / 5.0
      if strength <= 0
        [nil, [0, 0]]
      else
        blur_radius = (10 * strength * scale).to_i
        shadow_alpha = [(150 * strength) / 255.0, 1.0].min
        offset_x = (SHADOW_OFFSET[0] * scale).to_i
        offset_y = (SHADOW_OFFSET[1] * scale).to_i
        if @corner_radius > 0
          radius_pixels = corner_radius_pixels(image_width, image_height)
        else
          radius_pixels = 0
        end
        extra_margin = blur_radius * 5
        expanded_width = image_width + offset_x.abs + extra_margin
        expanded_height = image_height + offset_y.abs + extra_margin
        shadow_x = (extra_margin / 2) + [offset_x, 0].max
        shadow_y = (extra_margin / 2) + [offset_y, 0].max
        canvas = blank_surface(expanded_width, expanded_height)
        context = Cairo::Context.new(canvas)
        SHADOW_STEPS.times do |step|
          t = (step + 1).to_f / SHADOW_STEPS
          spread = blur_radius * t
          context.set_source_rgba(
            0,
            0,
            0,
            shadow_alpha * ((1 - t)**2) / SHADOW_STEPS,
          )
          rounded_rectangle(
            context,
            [shadow_x - spread, shadow_y - spread, image_width + (spread * 2), image_height + (spread * 2)],
            radius_pixels + spread,
          )
          context.fill
        end
        [canvas, [shadow_x, shadow_y]]
      end
    end

    def fill_color(context, color)
      red, green, blue, alpha = color
      context.set_source_rgba(
        red / 255.0,
        green / 255.0,
        blue / 255.0,
        (alpha || 255) / 255.0,
      )
      context.operator = Cairo::OPERATOR_SOURCE
    end

    def rounded_rectangle(context, rect, radius)
      x, y, width, height = rect
      r = [radius, width / 2, height / 2].min
      if r > 0
        context.new_sub_path
        context.arc(
          x + width - r,
          y + r,
          r,
          -Math::PI / 2,
          0,
        )
        context.arc(
          x + width - r,
          y + height - r,
          r,
          0,
          Math::PI / 2,
        )
        context.arc(
          x + r,
          y + height - r,
          r,
          Math::PI / 2,
          Math::PI,
        )
        context.arc(
          x + r,
          y + r,
          r,
          Math::PI,
          3 * Math::PI / 2,
        )
        context.close_path
      else
        context.rectangle(
          x,
          y,
          width,
          height,
        )
      end
    rescue StandardError
      context.rectangle(
        x,
        y,
        width,
        height,
      )
    end

    def composite!(onto, surface, x, y)
      Cairo::Context.new(onto).tap do |context|
        context.set_source(surface, x, y)
        context.paint
      end
      onto
    end

    def blank_surface(width, height)
      Cairo::ImageSurface.new(Cairo::FORMAT_ARGB32, [1, width.to_i].max, [1, height.to_i].max)
    end

    def pixbuf_to_surface(pixbuf)
      blank_surface(pixbuf.width, pixbuf.height).tap do |surface|
        Cairo::Context.new(surface).tap do |context|
          context.operator = Cairo::OPERATOR_SOURCE
          context.set_source_pixbuf(pixbuf, 0, 0)
          context.paint
        end
      end
    end

    # The reverse of `pixbuf_to_surface`: Cairo stores ARGB32 pixels
    # premultiplied, byte order BGRA on a little-endian machine, while
    # GdkPixbuf wants straight (non-premultiplied) RGBA — so every pixel is
    # unpremultiplied and its channels reordered on the way out.
    def surface_to_pixbuf(surface)
      surface.flush
      width = surface.width
      height = surface.height
      stride = surface.stride
      rowstride = width * 4
      raw = surface.data
      rgba = String.new(encoding: Encoding::BINARY)

      height.times do |y|
        bytes = raw.byteslice(y * stride, rowstride).unpack('C*')
        out_row = Array.new(rowstride, 0)
        i = 0
        while i < rowstride
          b, g, r, a = bytes[i], bytes[i + 1], bytes[i + 2], bytes[i + 3]
          if a.zero?
            out_row[i] = out_row[i + 1] = out_row[i + 2] = out_row[i + 3] = 0
          else
            out_row[i] = (r * 255) / a
            out_row[i + 1] = (g * 255) / a
            out_row[i + 2] = (b * 255) / a
            out_row[i + 3] = a
          end
          i += 4
        end
        rgba << out_row.pack('C*')
      end

      GdkPixbuf::Pixbuf.new(
        data:            rgba,
        colorspace:      :rgb,
        has_alpha:       true,
        bits_per_sample: 8,
        width:           width,
        height:          height,
        rowstride:       rowstride,
      )
    end

    def full_resolution_dimensions(processed_pixbuf)
      preview = @loaded_image.preview_image
      full = @loaded_image.full_res_image
      unless preview && full
        raise 'No images loaded'
      end

      scale = [full.width.to_f / preview.width, full.height.to_f / preview.height].max
      [(processed_pixbuf.width * scale).to_i, (processed_pixbuf.height * scale).to_i]
    end
end
