# frozen_string_literal: true

require 'adwaita'
require_relative 'app_constants'

# AboutDialog is the About window: credits, links, licence, and the two
# acknowledgement sections upstream adds by hand.
#
# Ported from gradia/ui/ui_parts.py (the AboutDialog class). Upstream's
# acknowledgement lists end in a None, which is how a NULL-terminated C array
# is written from Python; the Ruby binding takes the array as it is.
class AboutDialog
  COMMENTS = 'Make your images ready for all'
  DEVELOPER_NAME = 'Alexander Vanhee'
  COPYRIGHT = 'Copyright © 2025 Alexander Vanhee'

  DEVELOPERS = [
    'Alexander Vanhee https://github.com/AlexanderVanhee',
    'tfuxu https://github.com/tfuxu',
  ].freeze

  DESIGNERS = ['drpetrikov https://github.com/drpetrikov'].freeze

  BORROWED_FROM = [
    'Switcheroo https://apps.gnome.org/en-GB/Converter/',
    'Halftone https://github.com/tfuxu/Halftone',
    'Gradience https://github.com/GradienceTeam/Gradience',
    'Emblem https://apps.gnome.org/en-GB/Emblem/',
    'Builder https://apps.gnome.org/en-GB/Builder/',
  ].freeze

  IMAGE_SOURCES = [
    'GNOME backgrounds https://gitlab.gnome.org/GNOME/gnome-backgrounds',
    'Fruit Basket https://unsplash.com/photos/background-pattern-oWr5S1bO2ak',
    'Codioful https://unsplash.com/@codioful',
  ].freeze

  def initialize(version:)
    @version = version
  end

  def show(parent = nil)
    dialog.present(parent)
  end

  def dialog
    @dialog ||= Adwaita::AboutDialog.new.tap do |about|
      about.application_name = 'Gradia'
      about.version = @version
      about.comments = COMMENTS
      about.website = AppConstants::WEBSITE
      about.issue_url = AppConstants::ISSUE_URL
      about.developer_name = DEVELOPER_NAME
      about.developers = DEVELOPERS
      about.designers = DESIGNERS
      about.application_icon = AppConstants::APP_ID
      # Translators: a place for the translator's own credits, not a string to
      # translate literally.
      about.translator_credits = 'translator-credits'
      about.copyright = COPYRIGHT
      about.license_type = Gtk::License::GPL_3_0
      about.add_acknowledgement_section('Code and Design Borrowed from', BORROWED_FROM)
      about.add_acknowledgement_section('Image Sources', IMAGE_SOURCES)
    end
  end
end
