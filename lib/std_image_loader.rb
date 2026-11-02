# frozen_string_literal: true

require 'adwaita'
require 'fileutils'
require 'securerandom'
require_relative 'logger'
require_relative 'timestamp_filename'

# StdinImageLoader reads an image piped into the app on standard input and
# leaves it on disk as a PNG, so the rest of the app can treat it like any
# other opened file.
#
# Ported from gradia/utils/std_image_loader.py. Upstream decodes the bytes with
# PIL; this port writes them out and hands them to GdkPixbuf, which both
# validates the format and does the PNG re-encode.
class StdinImageLoader
  attr_reader :temp_path

  def initialize(logger: GradiaLogger.new, input: $stdin)
    @logger = logger
    @input = input
    @temp_path = nil
  end

  # The cache directory survives the Flatpak sandbox, which is why upstream
  # puts the spill file there rather than in /tmp.
  def flatpak_safe_temp_dir
    File.join(ENV.fetch('XDG_CACHE_HOME', File.expand_path('~/.cache')), 'gradia', 'stdin').tap do |dir|
      FileUtils.mkdir_p(dir)
    end
  end

  # nil when there is nothing piped in, or when what was piped in is not an
  # image — the caller then carries on to the welcome page.
  def read_from_stdin
    if @input.tty?
      nil
    else
      decode(@input.binmode.read)
    end
  end

  private

    def decode(image_data)
      if image_data.nil? || image_data.empty?
        @logger.critical('No image data received from stdin.')
      else
        convert(image_data)
      end
    end

    def convert(image_data)
      @logger.debug('Reading image from stdin…')
      spill(image_data).then do |spill_path|
        write_png(spill_path).tap { FileUtils.rm_f(spill_path) }
      end
    rescue StandardError => error
      @logger.critical('Failed to read image from stdin.', exception: error, show_exception: true)
      nil
    end

    def spill(image_data)
      File.join(flatpak_safe_temp_dir, "stdin_#{SecureRandom.hex(6)}").tap do |path|
        File.binwrite(path, image_data)
      end
    end

    def write_png(spill_path)
      GdkPixbuf::Pixbuf.new(file: spill_path).then do |pixbuf|
        target_path.tap do |path|
          pixbuf.save(path, 'png')
          @temp_path = path
          @logger.info("Temporary image file written to: #{@temp_path}")
        end
      end
    end

    def target_path
      TimestampedFilenameGenerator.new.generate('Edited Image From %Y-%m-%d %H-%M-%S').then do |filename|
        File.join(flatpak_safe_temp_dir, "#{filename}.png")
      end
    end
end
