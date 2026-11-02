# frozen_string_literal: true

require 'adwaita'

require_relative '../app_constants'
require_relative '../about_dialog'
require_relative '../app_menu'
require_relative '../logger'
require_relative '../settings'
require_relative '../shortcuts_dialog'
require_relative '../style'
require_relative 'rb/version'

module Gradia
  # Application is the port's entry point: it installs the stylesheet and the
  # icons the app ships, opens the window, and owns the window actions the
  # primary menu drives.
  #
  # Ported from gradia/main.py — the GApplication subclass there does the same
  # three things before handing over to the window. The window itself
  # (gradia/ui/window.py) is not ported yet, so the actions it owns that need
  # the editor are not registered; the menu greys those items out on its own.
  class Application
    DONATE_URI = 'https://ko-fi.com/alexandervanhee'

    # name => accelerators, as upstream's create_action calls declare them.
    WINDOW_ACTIONS = {
      'shortcuts' => ['<primary>question'],
      'about'     => [],
      'donate'    => [],
    }.freeze

    def build
      app.tap do
        app.signal_connect('activate') do
          Adwaita.init
          icon_theme.add_search_path(AppConstants::ICONS_DIR)
          style.apply
          register_actions

          window.tap do |win|
            win.content = toolbar_view
          end

          toolbar_view.tap do |view|
            view.add_top_bar(header_bar)
            view.content = status_page

            header_bar.tap do |bar|
              bar.pack_end(app_menu.button)
            end
          end

          window.present
        end
      end
    end

    def run(argv = []) = app.run(argv)

    def version = Gradia::Rb::VERSION

    # Adwaita::Application is broken in the Ruby bindings, so the application
    # object comes from Gtk. Adwaita::ApplicationWindow does work with this
    # gem (adwaita 4.3.9 / libadwaita 1.9) and is the window the port needs:
    # Adw dialogs present inside it as sheets, which is what the About and
    # shortcuts dialogs expect.
    def app = @app ||= Gtk::Application.new(AppConstants::PORT_APP_ID, :default_flags)

    def window
      @window ||= Adwaita::ApplicationWindow.new(app).tap do |win|
        win.title = 'Gradia'
        win.set_default_size(800, 600)
      end
    end

    def toolbar_view
      @toolbar_view ||= Adwaita::ToolbarView.new.tap do |view|
        view.top_bar_style = :flat
      end
    end

    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def app_menu = @app_menu ||= AppMenu.new

    def status_page
      @status_page ||= Adwaita::StatusPage.new.tap do |page|
        page.title = 'Gradia'
        page.description = AboutDialog::COMMENTS
        page.icon_name = AppConstants::APP_ID
      end
    end

    def settings = @settings ||= Settings.new

    def style = @style ||= Style.new

    def logger = @logger ||= GradiaLogger.new

    def about_dialog = @about_dialog ||= AboutDialog.new(version: version)

    def shortcuts_dialog = @shortcuts_dialog ||= ShortcutsDialog.new(window)

    def icon_theme = @icon_theme ||= Gtk::IconTheme.get_for_display(Gdk::Display.default)

    private

      def register_actions
        WINDOW_ACTIONS.each do |name, accelerators|
          Gio::SimpleAction.new(name).tap do |action|
            action.signal_connect('activate') { activate_action(name) }
            window.add_action(action)
          end

          unless accelerators.empty?
            app.set_accels_for_action("win.#{name}", accelerators)
          end
        end
      end

      def activate_action(name)
        case name
        when 'shortcuts' then shortcuts_dialog.show
        when 'about' then about_dialog.show(window)
        when 'donate' then Gtk::UriLauncher.new(DONATE_URI).launch(window)
        end
      end
  end
end
