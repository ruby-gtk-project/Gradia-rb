# frozen_string_literal: true

require_relative 'gradient'

# AppConstants holds the values upstream hard-codes: the gradient presets the
# sidebar offers, the wallpapers shipped with the app, and the export formats
# the save dialog lists.
#
# Ported from gradia/app_constants.py, plus the paths gradia/constants.in fills
# in at build time. Upstream's preset images are GResource paths baked into the
# binary; a Ruby checkout has no resource bundle, so they resolve to the files
# under this repository's data/ directory instead.
module AppConstants
  APP_ID = 'be.alexandervanhee.gradia'

  # The port's own application id, so an installed upstream Gradia and this
  # port can hold their own settings and windows side by side.
  PORT_APP_ID = 'org.rubygtkproject.Gradia'

  WEBSITE = 'https://github.com/AlexanderVanhee/Gradia'
  ISSUE_URL = 'https://github.com/AlexanderVanhee/Gradia/issues'

  ROOT_DIR = File.expand_path('..', __dir__)
  DATA_DIR = File.join(ROOT_DIR, 'data')
  IMAGES_DIR = File.join(DATA_DIR, 'images')
  ICONS_DIR = File.join(DATA_DIR, 'icons')
  SOURCE_STYLES_DIR = File.join(DATA_DIR, 'source-styles')

  # Upstream writes these presets' steps as hex (#f66151), while every other
  # gradient in the app — and the only form Gradient's renderer parses — is
  # "rgb(r,g,b)". The same colours are spelled the parseable way here, so a
  # preset renders as well as it previews.
  PREDEFINED_GRADIENTS = [
    Gradient.new(mode: 'linear', steps: [[0.0, 'rgb(246,97,81)'], [1.0, 'rgb(237,51,59)']], angle: 45, name: 'Red Flame'),
    Gradient.new(mode: 'linear', steps: [[0.0, 'rgb(255,95,109)'], [1.0, 'rgb(255,195,113)']], angle: 45, name: 'Sunset Orange'),
    Gradient.new(mode: 'linear', steps: [[0.0, 'rgb(255,210,0)'], [1.0, 'rgb(247,151,30)']], angle: 135, name: 'Golden Hour'),
    Gradient.new(
      mode:  'linear',
      steps: [[0.0, 'rgb(223,255,205)'], [0.5, 'rgb(144,249,196)'], [1.0, 'rgb(57,243,187)']],
      angle: 135,
      name:  'Mint Fresh',
    ),
    Gradient.new(mode: 'linear', steps: [[0.0, 'rgb(87,227,137)'], [1.0, 'rgb(53,132,228)']], angle: 135, name: 'Ocean Breeze'),
    Gradient.new(
      mode:  'linear',
      steps: [[0.0, 'rgb(35,212,253)'], [0.5, 'rgb(58,152,240)'], [1.0, 'rgb(183,33,255)']],
      angle: 45,
      name:  'Purple Dream',
    ),
  ].freeze

  PRESET_IMAGE_NAMES = %w[
    adwaita.webp
    blobs.webp
    coral.webp
    drool.webp
    graph.png
    mesh.webp
    pink.webp
    sky.webp
    swirl.webp
  ].freeze

  PRESET_IMAGES = PRESET_IMAGE_NAMES.map { |basename| File.join(IMAGES_DIR, basename) }.freeze

  SUPPORTED_EXPORT_FORMATS = {
    'png'  => {
      'name'         => 'PNG Image (*.png)',
      'shortname'    => 'PNG',
      'mime_type'    => 'image/png',
      'extensions'   => ['.png'],
      'save_options' => { 'keys' => [], 'values' => [] },
    },
    'jpeg' => {
      'name'         => 'JPEG Image (*.jpg)',
      'shortname'    => 'JPEG',
      'mime_type'    => 'image/jpeg',
      'extensions'   => ['.jpg', '.jpeg'],
      'save_options' => { 'keys' => ['quality'], 'values' => ['90'] },
    },
    'webp' => {
      'name'         => 'WebP Image (*.webp)',
      'shortname'    => 'WebP',
      'mime_type'    => 'image/webp',
      'extensions'   => ['.webp'],
      'save_options' => { 'keys' => ['quality'], 'values' => ['90'] },
    },
  }.freeze

  DEFAULT_EXPORT_FORMAT = 'jpeg'

  module_function

  # The format entry an extension belongs to, or nil when it belongs to none.
  def export_format_for(extension)
    SUPPORTED_EXPORT_FORMATS.find { |_key, format| format['extensions'].include?(extension.to_s.downcase) }
  end

  def help_text = File.read(File.join(DATA_DIR, 'help.txt'))
end
