# frozen_string_literal: true

require 'adwaita'
require 'fileutils'
require_relative 'background'
require_relative 'app_constants'
require_relative 'logger'

# ImageBackground fills the canvas with a picture, scaled to cover and cropped
# to the centre, and remembers the last one chosen so the next launch opens on
# it.
#
# Ported from gradia/graphics/image.py (the ImageBackground class; the selector
# widget from the same file lives in lib/image_selector.rb). Upstream holds the
# picture as a PIL image and reads the shipped presets out of a GResource
# bundle; this port holds a GdkPixbuf::Pixbuf and reads them from data/images.
class ImageBackground < Background
  attr_reader :file_path, :image, :load_error

  def initialize(file_path: nil, logger: GradiaLogger.new)
    super()
    @logger = logger
    FileUtils.mkdir_p(File.dirname(saved_image_path))

    if file_path
      load_image(file_path)
    else
      load_initial_image
    end
  end

  # Where the copy of the current background lives between runs.
  def saved_image_path
    File.join(ENV.fetch('XDG_CACHE_HOME', File.expand_path('~/.cache')), 'gradia', 'last_image.png')
  end

  # Upstream lets a load failure propagate; the port records it instead, so a
  # preset in a format the local gdk-pixbuf has no loader for leaves the
  # sidebar usable rather than taking the window down with it.
  def load_image(path)
    @file_path = path
    @image = GdkPixbuf::Pixbuf.new(file: path)
    @load_error = nil
    @image
  rescue StandardError => error
    @image = nil
    @load_error = error.message
    @logger.error("Failed to load background image #{path}", exception: error, show_exception: true)
    nil
  end

  def name = "image-#{@file_path || 'none'}"

  # Saved on a thread, as upstream does, because the sidebar calls this on
  # every pick and a full-size PNG write is slow enough to show.
  def save_image_copy_async
    Thread.new do
      if @image
        save_image_copy
      end
    end
  end

  def save_image_copy
    FileUtils.mkdir_p(File.dirname(saved_image_path))
    @image.save(saved_image_path, 'png')
  rescue StandardError => error
    @logger.error('Failed to save the background image copy', exception: error, show_exception: true)
    nil
  end

  def prepare_image(width, height)
    if @image
      cover_surface(width, height)
    end
  end

  private

    def load_initial_image
      if File.exist?(saved_image_path)
        load_image(saved_image_path)
      else
        load_image(AppConstants::PRESET_IMAGES.first)
      end
    end

    # Scale so the shorter side matches, then take the middle out — the same
    # resize-and-crop upstream does with PIL.
    def cover_surface(width, height)
      cover_size(width, height).then do |(scaled_width, scaled_height)|
        blank_surface(width, height).tap do |surface|
          Cairo::Context.new(surface).tap do |context|
            context.operator = Cairo::OPERATOR_SOURCE
            context.set_source_pixbuf(
              @image.scale_simple(scaled_width, scaled_height, :bilinear),
              -((scaled_width - surface.width) / 2),
              -((scaled_height - surface.height) / 2),
            )
            context.paint
          end
        end
      end
    end

    def cover_size(width, height)
      image_ratio = @image.width.to_f / @image.height
      target_ratio = width.to_f / height

      if image_ratio > target_ratio
        [(height * image_ratio).to_i, height.to_i]
      else
        [width.to_i, (width / image_ratio).to_i]
      end
    end
end
