# frozen_string_literal: true

require 'adwaita'

require_relative 'about_dialog'
require_relative 'app_constants'
require_relative 'app_menu'
require_relative 'background_selector'
require_relative 'logger'
require_relative 'screenshot_portal'
require_relative 'settings'
require_relative 'shortcuts_dialog'
require_relative 'style'
require_relative 'welcome_page'
require_relative 'gradia/rb/version'

module Gradia
  # Application is the port's entry point: it installs the stylesheet and the
  # icons the app ships, opens the window, and owns the window actions the
  # primary menu and the sidebar drive.
  #
  # Ported from gradia/main.py — the GApplication subclass there does the same
  # three things before handing over to the window.
  #
  # The window itself (gradia/ui/window.py) is not ported yet, so what lives
  # here is the part of it the ported components need: the overlay split view,
  # the welcome page in its content area and the background selector in its
  # sidebar, which is where gradia/ui/image_sidebar.py puts it. The actions
  # that need the unported loaders, exporters and overlays — `open`,
  # `open-path`, `load-drop`, `create-source-image`, `preferences` and the
  # rest — are not registered, so GTK leaves every button and menu item
  # pointing at them insensitive rather than failing when pressed.
  #
  # `screenshot` is the exception: it is registered and drives the real XDG
  # Screenshot portal through the `ashpd` gem (see ScreenshotPortal). The
  # image it captures has nowhere to go yet — the loader pipeline those other
  # actions wait on — so it is written to the cache directory and logged
  # rather than displayed.
  class Application
    DONATE_URI = 'https://ko-fi.com/alexandervanhee'

    # name => accelerators, as upstream's create_action calls declare them.
    WINDOW_ACTIONS = {
      'shortcuts'      => ['<primary>question'],
      'about'          => [],
      'donate'         => [],
      'quit'           => ['<primary>q', '<primary>w'],
      'toggle-sidebar' => ['F9'],
      'screenshot'     => [],
    }.freeze

    # Actions upstream declares with a parameter type, which decides both the
    # Gio::SimpleAction and the way the menu or widget addresses it. The Ruby
    # binding unwraps the GLib::Variant on the way into the handler, so the
    # parameter arrives as a plain Ruby value.
    PARAMETERISED_WINDOW_ACTIONS = { 'sidebar-shown' => 'b' }.freeze

    def build
      app.tap do
        app.signal_connect('activate') do
          Adwaita.init
          icon_theme.add_search_path(AppConstants::ICONS_DIR)
          style.apply
          register_actions
          app.add_window(window)

          window.tap do |win|
            win.content = split_view
          end

          split_view.tap do |view|
            view.sidebar = sidebar_toolbar_view
            view.content = welcome_page.build

            sidebar_toolbar_view.tap do |sidebar|
              sidebar.add_top_bar(sidebar_header_bar)
              sidebar.content = sidebar_scroller

              sidebar_scroller.tap do |scroller|
                scroller.child = sidebar_clamp

                sidebar_clamp.tap { |clamp| clamp.child = background_selector.build }
              end
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
        win.set_default_size(975, 675)
      end
    end

    # Upstream's main window hides the sidebar until an image is loaded and
    # gives it 300px; with no loader ported there is nothing to wait for, so
    # it opens shown.
    def split_view
      @split_view ||= Adwaita::OverlaySplitView.new.tap do |view|
        view.sidebar_width_fraction = 0.3
        view.max_sidebar_width = 300
        view.min_sidebar_width = 300
        view.show_sidebar = true
      end
    end

    def sidebar_toolbar_view = @sidebar_toolbar_view ||= Adwaita::ToolbarView.new

    def sidebar_header_bar
      @sidebar_header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
        bar.centering_policy = :loose
      end
    end

    def sidebar_scroller
      @sidebar_scroller ||= Gtk::ScrolledWindow.new.tap do |scroller|
        scroller.hscrollbar_policy = :never
        scroller.vscrollbar_policy = :automatic
      end
    end

    def sidebar_clamp
      @sidebar_clamp ||= Adwaita::Clamp.new.tap do |clamp|
        clamp.maximum_size = 400
        clamp.margin_top = 12
        clamp.margin_bottom = 12
        clamp.margin_start = 12
        clamp.margin_end = 12
      end
    end

    def welcome_page = @welcome_page ||= WelcomePage.new(app_menu: app_menu)

    def background_selector = @background_selector ||= BackgroundSelector.new(settings: settings, logger: logger)

    def app_menu = @app_menu ||= AppMenu.new

    def settings = @settings ||= Settings.new

    def style = @style ||= Style.new

    def logger = @logger ||= GradiaLogger.new

    def about_dialog = @about_dialog ||= AboutDialog.new(version: version)

    def shortcuts_dialog = @shortcuts_dialog ||= ShortcutsDialog.new(window)

    def screenshot_portal
      @screenshot_portal ||= ScreenshotPortal.new(
        window: window,
        logger: logger,
      )
    end

    def icon_theme = @icon_theme ||= Gtk::IconTheme.get_for_display(Gdk::Display.default)

    private

      def register_actions
        WINDOW_ACTIONS.each do |name, accelerators|
          add_action(Gio::SimpleAction.new(name), name)
          set_accels(name, accelerators)
        end

        PARAMETERISED_WINDOW_ACTIONS.each do |name, type|
          add_action(Gio::SimpleAction.new(name, GLib::VariantType.new(type)), name)
        end
      end

      def add_action(action, name)
        action.tap do |simple_action|
          simple_action.signal_connect('activate') { |_action, parameter| activate_action(name, parameter) }
          window.add_action(simple_action)
        end
      end

      def set_accels(name, accelerators)
        unless accelerators.empty?
          app.set_accels_for_action("win.#{name}", accelerators)
        end
      end

      def activate_action(name, parameter)
        case name
        when 'shortcuts' then shortcuts_dialog.show
        when 'about' then about_dialog.show(window)
        when 'donate' then Gtk::UriLauncher.new(DONATE_URI).launch(window)
        when 'quit' then window.close
        when 'toggle-sidebar' then split_view.show_sidebar = !split_view.show_sidebar?
        when 'sidebar-shown' then split_view.show_sidebar = parameter
        when 'screenshot' then screenshot_portal.capture
        end
      end
  end
end
