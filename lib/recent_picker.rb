# frozen_string_literal: true

require 'adwaita'
require 'pathname'
require_relative 'app_constants'
require_relative 'logger'
require_relative 'settings'
require_relative 'shadowed_image_card'

# RecentFile is one candidate thumbnail: the image's path, and the folder it
# came out of.
#
# Ported from gradia/ui/recent_picker.py (the RecentFile class).
RecentFile = Data.define(:path) do
  def folder = File.dirname(path)
  def name = File.basename(path)
end

# RecentImageGetter finds the most recent screenshots to offer on the welcome
# page: the folder set in the preferences, or Pictures/Screenshots.
#
# Ported from gradia/ui/recent_picker.py (the RecentImageGetter class). It
# returns nil — not an empty list — when there is no folder to look in, which
# is how the picker knows to show its "folder not found" overlay.
class RecentImageGetter
  MAX_RESULTS = 6
  IMAGE_EXTENSIONS = ['.png', '.jpg', '.jpeg', '.webp', '.avif'].freeze

  def initialize(settings: nil, logger: GradiaLogger.new)
    @settings = settings || Settings.new
    @logger = logger
  end

  def recent_screenshot_files
    screenshots_directory.then do |directory|
      if directory
        newest_in(directory)
      else
        @logger.info('Screenshots directory does not exist')
        nil
      end
    end
  end

  def screenshots_directory
    if @settings.screenshot_folder
      existing(@settings.screenshot_folder)
    else
      default_directory
    end
  end

  private

    def default_directory
      GLib.get_user_special_dir(GLib::UserDirectory::PICTURES).then do |pictures|
        if pictures
          existing(File.join(pictures, 'Screenshots'))
        end
      end
    end

    def existing(path)
      if File.directory?(path)
        path
      end
    end

    def newest_in(directory)
      Dir.children(directory)
        .map { |entry| File.join(directory, entry) }
        .select { |path| image?(path) }
        .sort_by { |path| -File.mtime(path).to_f }
        .first(MAX_RESULTS)
        .map { |path| RecentFile.new(path: path) }
    end

    def image?(path)
      File.file?(path) && IMAGE_EXTENSIONS.include?(File.extname(path).downcase)
    end
end

# RecentPicker is the grid of six recent screenshots on the welcome page, each
# card sitting on one of the predefined gradients, with a "folder not found"
# overlay when there is nowhere to read them from.
#
# Ported from gradia/ui/recent_picker.py and data/ui/recent_picker.blp.
# Upstream publishes `compact` as a GObject property that a breakpoint flips;
# the port exposes it as a setter the page calls from its own breakpoint
# handler, which rebuilds the cards the same way upstream's notify handler does.
class RecentPicker
  CARD_COUNT = 6
  IMAGE_SIZE = [260, 160].freeze
  COMPACT_IMAGE_SIZE = [150, 120].freeze
  CARD_PADDING = 10
  FULL_RADIUS = 4.0
  COMPACT_RADIUS = 2.0

  ERROR_TITLE = 'Screenshot Folder Not Found'
  ERROR_DESCRIPTION = 'Please set it in the Preferences menu'
  ERROR_BUTTON_LABEL = 'Open Preferences'

  attr_accessor :callback

  def initialize(callback: nil, image_getter: nil, compact: false)
    @callback = callback
    @image_getter = image_getter || RecentImageGetter.new
    @compact = compact
    @image_bins = []
    @recent_files = []
  end

  def build
    bin.tap do |root|
      root.child = overlay

      overlay.tap do |stack|
        stack.child = item_grid
        stack.add_overlay(error_overlay)

        item_grid.tap do |grid|
          grid.signal_connect('child-activated') { |_grid, child| on_image_clicked(@image_bins.index(child.child)) }
        end
      end

      error_overlay.tap do |box|
        box.append(error_title_label)
        box.append(error_description_label)
        box.append(preferences_button)
      end

      setup_cards
      load_images
    end
  end

  def compact? = @compact

  # Flipping this rebuilds the cards at the other size, as upstream's
  # notify::compact handler does.
  def compact=(value)
    unless @compact == value
      @compact = value
      setup_cards
      load_images
    end
  end

  def refresh = load_images

  def bin = @bin ||= Adwaita::Bin.new
  def overlay = @overlay ||= Gtk::Overlay.new

  def item_grid
    @item_grid ||= Gtk::FlowBox.new.tap do |grid|
      grid.row_spacing = 10
      grid.column_spacing = 10
      grid.halign = :center
      grid.homogeneous = true
      grid.max_children_per_line = 3
      grid.min_children_per_line = 2
      grid.selection_mode = :none
      grid.add_css_class('recent-button-flowbox')
    end
  end

  def error_overlay
    @error_overlay ||= Gtk::Box.new(:vertical, 12).tap do |box|
      box.valign = :center
    end
  end

  def error_title_label
    @error_title_label ||= Gtk::Label.new(ERROR_TITLE).tap do |label|
      label.add_css_class('title-2')
    end
  end

  def error_description_label
    @error_description_label ||= Gtk::Label.new(ERROR_DESCRIPTION).tap do |label|
      label.margin_bottom = 12
    end
  end

  def preferences_button
    @preferences_button ||= Gtk::Button.new.tap do |button|
      button.label = ERROR_BUTTON_LABEL
      button.action_name = 'win.preferences'
      button.halign = :center
      button.add_css_class('pill')
    end
  end

  private

    def card_size
      if @compact
        COMPACT_IMAGE_SIZE
      else
        IMAGE_SIZE
      end
    end

    def card_radius
      if @compact
        COMPACT_RADIUS
      else
        FULL_RADIUS
      end
    end

    def setup_cards
      item_grid.remove_all
      @image_bins = Array.new(CARD_COUNT) { |index| card_bin(index) }
      @image_bins.each { |image_bin| item_grid.append(image_bin) }
    end

    def card_bin(index)
      Adwaita::Bin.new.tap do |image_bin|
        image_bin.set_size_request(*card_size)
        image_bin.add_css_class('card')
        image_bin.child = Gtk::Box.new(:vertical, 0)
        apply_gradient(image_bin, index)
      end
    end

    # Each card gets its own named CSS rule, because a gradient cannot be set
    # as a widget property.
    def apply_gradient(image_bin, index)
      "gradient-button-#{index}".then do |gradient_name|
        image_bin.name = gradient_name
        image_bin.add_css_class('recent-button')
        image_bin.style_context.add_provider(
          gradient_provider(gradient_name, index),
          Gtk::StyleProvider::PRIORITY_APPLICATION,
        )
      end
    end

    def gradient_provider(gradient_name, index)
      AppConstants::PREDEFINED_GRADIENTS[index % AppConstants::PREDEFINED_GRADIENTS.length].then do |gradient|
        Gtk::CssProvider.new.tap do |provider|
          provider.load_from_string("*##{gradient_name} { background-image: #{gradient.to_css}; }")
        end
      end
    end

    def gradient_index(index) = index % AppConstants::PREDEFINED_GRADIENTS.length

    def on_image_clicked(index)
      if index && index < @recent_files.length
        if @callback
          @callback.call(@recent_files[index].path, gradient_index(index))
        end
      end
    end

    def load_images = update_display(@image_getter.recent_screenshot_files)

    def update_display(recent_files)
      @recent_files = recent_files || []
      show_error(recent_files.nil?)

      CARD_COUNT.times do |index|
        if index < @recent_files.length
          fill_card(index, @recent_files[index])
        else
          empty_card(index)
        end
      end
    end

    def show_error(missing)
      error_overlay.visible = missing

      if missing
        item_grid.opacity = 0.25
      else
        item_grid.opacity = 1
      end
    end

    def fill_card(index, file)
      ShadowedImageCard.new(file.path, radius: card_radius, padding: CARD_PADDING, compact: @compact).then do |card|
        if card.loaded?
          attach_card(index, card, file)
        else
          empty_card(index)
        end
      end
    end

    def attach_card(index, card, file)
      @image_bins[index].tap do |image_bin|
        image_bin.child = card.build
        image_bin.sensitive = true
        image_bin.tooltip_text = file.name
        label_parent(image_bin, file.name)
      end
    end

    # The label belongs on the flow-box child, not the card, because that is the
    # focusable, activatable widget. Upstream sets it as the accessible LABEL
    # property; Gtk::Accessible#update_property takes an array of enum values,
    # which this binding raises NotImplementedError on rather than marshal, so
    # the label is set as the child's tooltip — the text assistive technology
    # falls back to when no explicit label is set.
    def label_parent(image_bin, label)
      image_bin.parent.then do |flowbox_child|
        if flowbox_child
          flowbox_child.tooltip_text = label
        end
      end
    end

    def empty_card(index)
      @image_bins[index].tap do |image_bin|
        image_bin.child = Gtk::Image.new.tap { |image| image.icon_name = 'image-missing-symbolic' }
        image_bin.sensitive = false
        image_bin.tooltip_text = ''
      end
    end
end
