# frozen_string_literal: true

require 'ashpd'
require 'fileutils'
require_relative 'logger'
require_relative 'timestamp_filename'

# ScreenshotPortal drives the XDG Screenshot portal to let the user grab a
# screenshot from inside the app, and spills the result to the same
# Flatpak-safe cache directory StdinImageLoader uses.
#
# Ported from the ScreenshotImageLoader in gradia/ui/image_loaders.py.
# Upstream talks to the portal through libportal's `Xdp.Portal`
# (gi.repository.Xdp), an async GObject API with its own request/finish pair.
# The Ruby binding for that namespace is `ashpd`, the Rust `ashpd` crate's
# gem: it exposes the same org.freedesktop.portal.Screenshot interface as a
# single blocking call, `Ashpd::Screenshot.capture(interactive, modal)`, so
# the port runs it on a background Thread and marshals the result back to
# the GLib main loop with GLib::Idle.add rather than juggling a
# request/finish callback pair.
#
# Upstream also hides the window for the duration of the portal's own
# screenshot-selection UI and restores the window's full image-loading
# pipeline (ImageOrigin, _set_image_and_update_ui) afterwards; that pipeline
# is not ported yet, so this class stops where StdinImageLoader does: the
# captured PNG lands in the cache directory and the caller is handed its
# path.
class ScreenshotPortal
  def initialize(window:, logger: GradiaLogger.new, on_success: nil, on_error: nil)
    @window = window
    @logger = logger
    @on_success = on_success
    @on_error = on_error
  end

  def capture
    @window.hide
    Thread.new { capture_via_portal }
  end

  def cache_dir
    File.join(ENV.fetch('XDG_CACHE_HOME', File.expand_path('~/.cache')), 'gradia', 'screenshots').tap do |dir|
      FileUtils.mkdir_p(dir)
    end
  end

  private

    # interactive: true shows the portal's own picker; modal: false lets the
    # picker sit above our (now hidden) window rather than blocking it.
    def capture_via_portal
      uri = Ashpd::Screenshot.capture(true, false)
      GLib::Idle.add { handle_uri(uri) }
    rescue StandardError => error
      GLib::Idle.add { handle_error(error) }
    end

    def handle_uri(uri)
      write_png(Gio::File.new_for_uri(uri)).tap do |path|
        @logger.info("Screenshot captured via portal: #{path}")
        @window.show
        @on_success&.call(path)
      end
      false
    end

    def handle_error(error)
      @logger.error("Screenshot portal request failed: #{error.message}")
      @window.show
      @on_error&.call(error.message)
      false
    end

    def write_png(file)
      _ok, contents, = file.load_contents
      File.join(cache_dir, "#{filename}.png").tap { |path| File.binwrite(path, contents.pack('C*')) }
    end

    def filename = TimestampedFilenameGenerator.new.generate('Screenshot From %Y-%m-%d %H-%M-%S')
end
