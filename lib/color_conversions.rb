# frozen_string_literal: true

require 'adwaita'

# Colors converts between the three colour representations the app passes
# around: hex strings (what the settings store), Gdk::RGBA (what the widgets
# want) and plain channel tuples (what the image code wants).
#
# Ported from gradia/utils/colors.py. Upstream relies on PyGObject making
# Gdk.RGBA iterable, so `*rgba` and `for c in rgba` work; the Ruby binding does
# not, so `components` is the explicit form of that and every helper here takes
# either an RGBA or an array of channels.
#
# Filed as color_conversions.rb rather than colors.rb: the cairo gem's own
# "cairo/color" does a bare `require "colors"` for the colors gem it depends
# on, and this file sitting on $LOAD_PATH as lib/colors.rb shadowed it,
# breaking `require "gtk4"` itself everywhere this app's lib/ is on RUBYLIB.
module Colors
  LUMINANCE_THRESHOLD = 130

  module_function

  # Channels of an RGBA (or a tuple already in channel form), 0.0–1.0.
  def components(color)
    case color
    when Gdk::RGBA then [color.red, color.green, color.blue, color.alpha]
    else Array(color).map(&:to_f)
    end
  end

  # Gdk::RGBA for a hex colour code. `alpha` overrides the parsed alpha, which
  # is what the callers that store colour and opacity separately need.
  def hex_to_rgba(hex_color, alpha = nil)
    Gdk::RGBA.parse(hex_color).tap do |rgba|
      if alpha
        rgba.alpha = alpha
      end
    end
  end

  # Hex representation of an RGBA, alpha included — eight digits, as upstream.
  def rgba_to_hex(rgba)
    components(rgba).map { |channel| format('%02x', (channel * 255).to_i) }.then do |(r, g, b, a)|
      "##{r}#{g}#{b}#{a}"
    end
  end

  # Raw 0–255 red, green and blue of a hex colour code.
  def hex_to_rgb(hex_color)
    hex_color.delete_prefix('#').then do |digits|
      [0, 2, 4].map { |i| digits[i, 2].to_i(16) }
    end
  end

  def has_visible_color?(color)
    components(color).then do |channels|
      channels.first(3).any?(&:positive?) || (channels.length > 3 && channels[3].positive?)
    end
  end

  # Whether white-on-colour would be unreadable. Fully transparent counts as
  # light, which is how the checkmark on a transparent swatch stays visible.
  def light_color_hex?(hex_color)
    hex_color.delete_prefix('#').then do |digits|
      case digits.length
      when 6 then luminance(*[0, 2, 4].map { |i| digits[i, 2].to_i(16) / 255.0 }, 1.0) > LUMINANCE_THRESHOLD
      when 8 then luminance(*[0, 2, 4, 6].map { |i| digits[i, 2].to_i(16) / 255.0 }) > LUMINANCE_THRESHOLD
      else raise ArgumentError, 'Invalid hex color format'
      end
    end
  end

  def light_color_rgba?(rgba) = luminance(*components(rgba)) > LUMINANCE_THRESHOLD

  # Upstream returns 255 — "as light as it gets" — for a fully transparent
  # colour, so that the contrast check falls on the dark-text side.
  def luminance(red, green, blue, alpha)
    if alpha.zero?
      255
    else
      (0.299 * red * 255) + (0.587 * green * 255) + (0.114 * blue * 255)
    end
  end

  # Parses the "rgb(r,g,b)" strings the gradient steps are stored as.
  def parse_rgb_string(string)
    string.to_s.strip.downcase.then do |text|
      unless text.start_with?('rgb(') && text.end_with?(')')
        raise ArgumentError, "Invalid rgb string: #{string}"
      end

      text[4..-2].split(',').map { |part| part.strip.to_i }
    end
  end

  # The inverse, for the gradient editor writing a picked colour back out.
  def rgb_string(color)
    components(color).first(3).map { |channel| (channel * 255).round }.then do |(r, g, b)|
      "rgb(#{r},#{g},#{b})"
    end
  end
end
