# frozen_string_literal: true

require 'adwaita'
require 'securerandom'
require_relative 'logger'

# Clipboard puts text and images on the system clipboard, and spills textures
# and pixbufs to a file when something else needs a path rather than pixels.
#
# Ported from gradia/clipboard.py. Upstream builds a Gdk.ContentProvider by
# hand; the Ruby binding exposes no ContentProvider constructors but does let
# Gdk::Clipboard#set take the value directly and wrap it itself, which is the
# same two content types — text/plain;charset=utf-8 and the texture — on the
# clipboard at the end of it.
module Clipboard
  TEMP_FILE_NAME = 'clipboard_temp.png'

  module_function

  def logger = @logger ||= GradiaLogger.new

  def save_texture_to_file(texture, temp_dir)
    File.join(temp_dir, "clipboard_image_#{SecureRandom.hex(6)}.png").tap do |temp_path|
      texture.save_to_png(temp_path)
    end
  end

  def save_pixbuf_to_path(temp_dir, pixbuf)
    File.join(temp_dir, TEMP_FILE_NAME).tap do |temp_path|
      pixbuf.save(temp_path, 'png')
    end
  end

  def copy_text_to_clipboard(text)
    with_clipboard { |clipboard| clipboard.set(text.to_s) }
  end

  def copy_pixbuf_to_clipboard(pixbuf)
    with_clipboard { |clipboard| clipboard.set(Gdk::Texture.new(pixbuf)) }
  end

  def with_clipboard
    Gdk::Display.default.then do |display|
      if display
        yield(display.clipboard)
      else
        logger.warning('Failed to retrieve `Gdk::Display` object.')
      end
    end
  end
end
