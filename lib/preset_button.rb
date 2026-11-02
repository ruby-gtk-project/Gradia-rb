# frozen_string_literal: true

require 'adwaita'
require_relative 'app_constants'
require_relative 'logger'

# PresetButton is the grid-of-samples menu button the gradient and image
# selectors hang off their group headers: a flat icon button whose popover
# holds a FlowBox of clickable previews, three to a line.
#
# Ported from gradia/ui/widget/preset_button.py (the BasePresetButton class).
# Upstream subclasses Gtk.MenuButton and declares the two preset flavours as
# GObject types so the blueprint can instantiate them; the port keeps the
# shared shape here and lets the two subclasses say what a preset is and what
# a sample of one looks like.
class PresetButton
  COLUMNS = 3

  def initialize(icon_name: 'view-grid-symbolic', &on_select)
    @icon_name = icon_name
    @on_select = on_select
  end

  def build
    menu_button.tap do |button|
      button.popover = popover

      popover.tap do |pop|
        pop.child = popover_box

        popover_box.tap do |box|
          box.append(flow_box)

          flow_box.tap do |flow|
            samples.each { |sample| flow.append(sample) }
            flow.signal_connect('child-activated') { |_flow, child| on_child_activated(child.index) }
          end
        end
      end
    end
  end

  def on_select(&block)
    @on_select = block
  end

  def menu_button
    @menu_button ||= Gtk::MenuButton.new.tap do |button|
      button.icon_name = @icon_name
      button.valign = :center
      button.add_css_class('flat')
    end
  end

  def popover = @popover ||= Gtk::Popover.new

  def popover_box
    @popover_box ||= Gtk::Box.new(:vertical, 8).tap do |box|
      box.margin_top = 8
      box.margin_bottom = 8
      box.margin_start = 8
      box.margin_end = 8
    end
  end

  def flow_box
    @flow_box ||= Gtk::FlowBox.new.tap do |flow|
      flow.max_children_per_line = COLUMNS
      flow.selection_mode = :none
      flow.homogeneous = true
      flow.row_spacing = 8
      flow.column_spacing = 8
    end
  end

  # One Adwaita::Bin per preset, in preset order, so a FlowBox child index is
  # an index into `presets`.
  def samples
    @samples ||= presets.each_with_index.map { |preset, index| sample(preset, index) }
  end

  private

    def on_child_activated(index)
      presets.fetch(index, nil).then do |preset|
        if preset
          popover.popdown
          if @on_select
            @on_select.call(preset)
          end
        end
      end
    end

    # The frame a sample is drawn in — upstream's `_create_bin`.
    def preset_bin(width, height)
      Adwaita::Bin.new.tap do |bin|
        bin.set_size_request(width, height)
        bin.add_css_class('preset-button')
        bin.add_css_class('flat')
      end
    end

    # Upstream attaches a CSS provider per sample at
    # PRIORITY_APPLICATION + 3 so the generated background beats both the
    # app stylesheet and the libadwaita theme.
    def apply_css(widget, css)
      Gtk::CssProvider.new.tap do |provider|
        provider.load_from_string(css)
        widget.style_context.add_provider(provider, Gtk::StyleProvider::PRIORITY_APPLICATION + 3)
      end
    end
end

# GradientPresetButton offers the six gradients AppConstants ships.
#
# Ported from gradia/ui/widget/preset_button.py (the GradientPresetButton
# class).
class GradientPresetButton < PresetButton
  PRESET_COUNT = 6
  SAMPLE_WIDTH = 60
  SAMPLE_HEIGHT = 40

  def presets = @presets ||= AppConstants::PREDEFINED_GRADIENTS.first(PRESET_COUNT)

  private

    # A gradient sample is an empty bin whose background-image is the
    # gradient's CSS. GTK's CSS engine has linear and radial gradients but no
    # conic one, so a conic preset previews as its first colour — the same
    # thing happens upstream, which builds this preview out of CSS too.
    def sample(gradient, _index)
      preset_bin(SAMPLE_WIDTH, SAMPLE_HEIGHT).tap do |bin|
        bin.tooltip_text = gradient.name.to_s
        apply_css(bin, ".preset-button { background-image: #{gradient.to_css}; }")
      end
    end
end

# ImagePresetButton offers the wallpapers the app ships in data/images.
#
# Ported from gradia/ui/widget/preset_button.py (the ImagePresetButton class).
class ImagePresetButton < PresetButton
  SAMPLE_WIDTH = 80
  SAMPLE_HEIGHT = 60

  def initialize(logger: GradiaLogger.new, &on_select)
    super(&on_select)
    @logger = logger
  end

  def presets = AppConstants::PRESET_IMAGES

  private

    def sample(path, _index)
      preset_bin(SAMPLE_WIDTH, SAMPLE_HEIGHT).tap do |bin|
        bin.tooltip_text = label_for(path)

        picture.tap do |pic|
          bin.child = pic
          load_async(path, bin, pic)
        end
      end
    end

    def picture
      Gtk::Picture.new.tap do |pic|
        pic.content_fit = :cover
        pic.halign = :fill
        pic.valign = :fill
        pic.hexpand = true
        pic.vexpand = true
      end
    end

    # "pink.webp" => "Pink"; upstream's _get_image_label.
    def label_for(path)
      File.basename(path, File.extname(path)).tr('-_', '  ').split.map(&:capitalize).join(' ')
    end

    # Upstream decodes each preset on a worker thread and hands the pixbuf
    # back through GLib.idle_add; nine wallpapers decoded on the main loop
    # would stall the first popover, so the port keeps the thread.
    def load_async(path, bin, pic)
      Thread.new do
        scaled_pixbuf(path).then do |pixbuf|
          GLib::Idle.add do
            show_sample(bin, pic, pixbuf)
            false
          end
        end
      end
    end

    def show_sample(bin, pic, pixbuf)
      if pixbuf
        pic.pixbuf = pixbuf
      else
        bin.child = missing_icon
      end
    end

    def missing_icon
      Gtk::Image.new.tap do |image|
        image.icon_name = 'image-missing-symbolic'
        image.pixel_size = 24
        image.halign = :center
        image.valign = :center
      end
    end

    # Scaled down to the sample's box, keeping the aspect ratio — the same
    # arithmetic as upstream's _on_preset_image_loaded.
    def scaled_pixbuf(path)
      GdkPixbuf::Pixbuf.new(file: path).then do |pixbuf|
        if pixbuf.width > SAMPLE_WIDTH || pixbuf.height > SAMPLE_HEIGHT
          sample_size(pixbuf).then { |(width, height)| pixbuf.scale_simple(width, height, :bilinear) }
        else
          pixbuf
        end
      end
    rescue StandardError => error
      @logger.error("Failed to load preset image #{path}", exception: error, show_exception: true)
      nil
    end

    def sample_size(pixbuf)
      (pixbuf.height * SAMPLE_WIDTH / pixbuf.width).then do |height|
        if height > SAMPLE_HEIGHT
          [pixbuf.width * SAMPLE_HEIGHT / pixbuf.height, SAMPLE_HEIGHT]
        else
          [SAMPLE_WIDTH, height]
        end
      end
    end
end
