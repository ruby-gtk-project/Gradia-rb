# frozen_string_literal: true

require 'adwaita'

# Background is the interface the three background kinds share: given a target
# size, hand back an image to composite the screenshot onto, and give a name
# that changes whenever the configuration does so the processor can cache on it.
#
# Ported from gradia/graphics/background.py. Upstream's `prepare_image` returns
# a PIL image; Ruby has no PIL, so every subclass here returns a
# Cairo::ImageSurface in ARGB32 instead — the same thing the drawing overlay and
# the exporter already speak.
class Background
  def prepare_image(width, height)
    raise NotImplementedError, "#{self.class} must implement prepare_image(#{width}, #{height})"
  end

  def name
    raise NotImplementedError, "#{self.class} must implement name"
  end

  # A blank ARGB32 surface of the requested size, which every subclass starts
  # from and which stands in for PIL's `Image.new`.
  def blank_surface(width, height)
    Cairo::ImageSurface.new(Cairo::FORMAT_ARGB32, [1, width.to_i].max, [1, height.to_i].max)
  end
end
