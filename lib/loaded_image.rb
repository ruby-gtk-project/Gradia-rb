# frozen_string_literal: true

require 'adwaita'
require_relative 'logger'

# ImageOrigin is where the image the window is editing came from. It decides
# the name and folder shown in the sidebar, and whether the close dialog treats
# the file as a screenshot worth offering to delete.
#
# Ported from gradia/graphics/loaded_image.py (the ImageOrigin enum).
module ImageOrigin
  FILE_DIALOG = :file_dialog
  DRAG_DROP = :drag_drop
  CLIPBOARD = :clipboard
  SCREENSHOT = :screenshot
  FAKE_SCREENSHOT = :fake_screenshot
  COMMAND_LINE = :command_line
  SOURCE_IMAGE = :source_image

  ALL = [FILE_DIALOG, DRAG_DROP, CLIPBOARD, SCREENSHOT, FAKE_SCREENSHOT, COMMAND_LINE, SOURCE_IMAGE].freeze

  # The origins with no file behind them worth naming after.
  SYNTHETIC = [CLIPBOARD, SCREENSHOT, FAKE_SCREENSHOT, SOURCE_IMAGE].freeze

  SCREENSHOTS = [SCREENSHOT, FAKE_SCREENSHOT].freeze
end

# BalancedPadding is how much padding each edge needs for an image whose own
# margins are uneven to end up centred, and the colour to pad with.
#
# Ported from gradia/graphics/loaded_image.py (the BalancedPadding dataclass).
BalancedPadding = Data.define(
  :top,
  :bottom,
  :left,
  :right,
  :color,
) do
  def max_padding = [top, bottom, left, right].max
  def total_horizontal = left + right
  def total_vertical = top + bottom
end

# LoadedImage is the image being edited: the full-resolution pixels, a preview
# downscaled to something the overlay can redraw at interactive speed, and the
# padding analysis the auto-balance option uses.
#
# Ported from gradia/graphics/loaded_image.py. Upstream holds PIL images; this
# port holds GdkPixbuf::Pixbuf, which is what the overlay and the exporter
# already draw from.
class LoadedImage
  MAX_PIXEL_AMOUNT = 1024 * 1024
  PADDING_TOLERANCE = 5

  attr_reader :image_path, :origin, :screenshot_path, :full_res_image, :preview_image, :balanced_padding, :load_error

  def initialize(image_path, origin, screenshot_path: nil, logger: GradiaLogger.new)
    @image_path = image_path
    @origin = origin
    @screenshot_path = screenshot_path
    @logger = logger
    load_and_analyze_image
  end

  def loaded? = @load_error.nil? && !@full_res_image.nil?

  # The name the sidebar shows. Synthetic origins get a label of their own
  # because there is no meaningful filename behind them.
  def proper_name(with_extension: true)
    case @origin
    when ImageOrigin::CLIPBOARD then 'Clipboard Image'
    when ImageOrigin::SCREENSHOT, ImageOrigin::FAKE_SCREENSHOT then 'Screenshot'
    when ImageOrigin::SOURCE_IMAGE then 'Generated Image'
    else basename(with_extension: with_extension)
    end
  end

  def proper_folder
    case @origin
    when ImageOrigin::CLIPBOARD then 'From clipboard'
    when ImageOrigin::SCREENSHOT, ImageOrigin::FAKE_SCREENSHOT then 'Screenshot'
    when ImageOrigin::SOURCE_IMAGE then 'Source'
    else File.basename(File.dirname(@image_path))
    end
  end

  def proper_name? = !ImageOrigin::SYNTHETIC.include?(@origin)

  def proper_folder? = !ImageOrigin::SYNTHETIC.include?(@origin)

  def folder_path = File.dirname(@image_path)

  def screenshot? = ImageOrigin::SCREENSHOTS.include?(@origin)

  private

    def basename(with_extension:)
      File.basename(@image_path).then do |filename|
        if with_extension
          filename
        else
          File.basename(filename, File.extname(filename))
        end
      end
    end

    def load_and_analyze_image
      if File.exist?(@image_path)
        load_pixbufs
      else
        @load_error = "Image file not found: #{@image_path}"
      end
    end

    # The pixbuf is given an alpha channel on the way in, as upstream converts
    # to RGBA, so the padding scan and the overlay can count on four channels.
    def load_pixbufs
      @full_res_image = GdkPixbuf::Pixbuf.new(file: @image_path).add_alpha(
        false,
        0,
        0,
        0,
      )
      @preview_image = create_preview_image(@full_res_image)
      @balanced_padding = analyze_padding(@preview_image)
    rescue StandardError => error
      @load_error = "Error loading image: #{error.message}"
      @logger.error("Failed to load #{@image_path}", exception: error, show_exception: true)
    end

    def create_preview_image(image)
      if needs_downscaling?(image)
        downscale_image(image)
      else
        image
      end
    end

    def needs_downscaling?(image) = (image.width * image.height) > MAX_PIXEL_AMOUNT

    def downscale_image(image)
      Math.sqrt(MAX_PIXEL_AMOUNT.to_f / (image.width * image.height)).then do |factor|
        image.scale_simple([1, (image.width * factor).to_i].max, [1, (image.height * factor).to_i].max, :bilinear)
      end
    end

    # Upstream measures how many rows and columns at each edge match the
    # top-left pixel, then pads the short edges up to the longest run so the
    # picture ends up optically centred.
    def analyze_padding(image)
      Scanner.new(image, PADDING_TOLERANCE).then do |scanner|
        [scanner.top, scanner.bottom, scanner.left, scanner.right].then do |(top, bottom, left, right)|
          BalancedPadding.new(
            top:    [top, bottom, left, right].max - top,
            bottom: [top, bottom, left, right].max - bottom,
            left:   [top, bottom, left, right].max - left,
            right:  [top, bottom, left, right].max - right,
            color:  scanner.reference_color,
          )
        end
      end
    end

  # Scanner counts the uniform border on each edge of a pixbuf.
  #
  # Upstream reads pixels through PIL's `load()` accessor; GdkPixbuf hands back
  # a flat byte array instead, so the row stride and channel count have to be
  # applied by hand.
    class Scanner
      def initialize(image, tolerance)
        @pixels = image.pixels
        @width = image.width
        @height = image.height
        @stride = image.rowstride
        @channels = image.n_channels
        @tolerance = tolerance
        @reference_color = pixel(0, 0)
      end

      attr_reader :reference_color

      # Each edge counts how many rows or columns match the reference colour. A
      # uniform image has no differing row at all, and upstream's fallback for
      # that is the full width or height.
      def top = (0...@height).find { |y| row_differs?(y) } || @height

      def bottom
        (0...@height).reverse_each.find { |y| row_differs?(y) }&.then { |y| @height - 1 - y } || @height
      end

      def left = (0...@width).find { |x| column_differs?(x) } || @width

      def right
        (0...@width).reverse_each.find { |x| column_differs?(x) }&.then { |x| @width - 1 - x } || @width
      end

      private

        def row_differs?(y) = @width.times.any? { |x| !similar?(pixel(x, y)) }

        def column_differs?(x) = @height.times.any? { |y| !similar?(pixel(x, y)) }

        def pixel(x, y)
          ((y * @stride) + (x * @channels)).then do |offset|
            Array.new(@channels) { |channel| @pixels[offset + channel] }
          end
        end

        def similar?(color)
          color.each_with_index.all? { |channel, index| (channel - @reference_color[index]).abs <= @tolerance }
        end
    end
end
