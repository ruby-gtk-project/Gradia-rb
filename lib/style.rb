# frozen_string_literal: true

require 'adwaita'
require_relative 'app_constants'
require_relative 'logger'

# Style installs the app stylesheet on the display, at the application
# priority, so the CSS classes the widgets ask for mean something.
#
# Ported from data/style.css, which upstream compiles into its GResource bundle
# and loads from gradia/main.py. The stylesheet itself is copied verbatim to
# data/style.css in this repository, so the rules stay diffable against
# upstream; this class is the loader for it.
class Style
  PATH = File.join(AppConstants::DATA_DIR, 'style.css')

  def initialize(path: PATH, logger: GradiaLogger.new)
    @path = path
    @logger = logger
  end

  def apply(display: Gdk::Display.default)
    if display
      install(display)
    else
      @logger.warning('No display to install the stylesheet on.')
    end
  end

  def css = File.read(@path)

  def provider
    @provider ||= Gtk::CssProvider.new.tap do |css_provider|
      css_provider.load_from_string(css)
    end
  end

  private

    def install(display)
      Gtk::StyleContext.add_provider_for_display(
        display,
        provider,
        Gtk::StyleProvider::PRIORITY_APPLICATION,
      )
    end
end
