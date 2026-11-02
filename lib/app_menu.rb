# frozen_string_literal: true

require 'adwaita'

# AppMenu is the primary menu behind the hamburger button: preferences, the
# shortcuts window, the donation link and About.
#
# Ported from the `menu app_menu` block that both data/ui/welcome_page.blp and
# data/ui/image_sidebar.blp declare — the same four items in the same order, so
# the two headers show one menu.
class AppMenu
  ITEMS = [
    ['_Preferences', 'win.preferences'],
    ['_Keyboard Shortcuts', 'win.shortcuts'],
    ['_Donate to Gradia', 'win.donate'],
    ['_About Gradia', 'win.about'],
  ].freeze

  TOOLTIP = 'Main Menu'

  # The model, for a MenuButton built elsewhere.
  def model
    @model ||= Gio::Menu.new.tap do |menu|
      menu.append_section(nil, section)
    end
  end

  def section
    @section ||= Gio::Menu.new.tap do |menu|
      ITEMS.each { |(label, action)| menu.append_item(Gio::MenuItem.new(label, action)) }
    end
  end

  # The button the header bars pack, already pointed at the model.
  def button
    @button ||= Gtk::MenuButton.new.tap do |menu_button|
      menu_button.icon_name = 'open-menu-symbolic'
      menu_button.tooltip_text = TOOLTIP
      menu_button.primary = true
      menu_button.menu_model = model
    end
  end
end
