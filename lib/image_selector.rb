# frozen_string_literal: true

require 'adwaita'
require_relative 'image_background'
require_relative 'logger'
require_relative 'preset_button'

# ImageSelector is the image page of the background sidebar: a Select Image
# row, a preview of the current picture that is itself a drop target and a
# second way to open the file chooser, and the shipped wallpapers behind the
# preset button in the group header.
#
# Ported from gradia/graphics/image.py (the ImageSelector class) and
# data/ui/selectors/image_selector.blp. Upstream previews by writing a
# downscaled PIL copy to a temporary file and handing Gtk.Picture the path,
# because PIL images are not paintables; an ImageBackground here already holds
# a GdkPixbuf::Pixbuf, so the preview is a scaled pixbuf and no temporary file
# is involved.
class ImageSelector
  PREVIEW_WIDTH = 250
  PREVIEW_HEIGHT = 88
  PREVIEW_MAX_WIDTH = 400

  MIME_TYPES = [
    'image/png',
    'image/jpg',
    'image/jpeg',
    'image/webp',
    'image/avif',
  ].freeze

  def initialize(image_background, logger: GradiaLogger.new, &on_change)
    @image_background = image_background
    @logger = logger
    @on_change = on_change
  end

  def build
    group.tap do |preferences|
      preferences.header_suffix = preset_button.build
      preferences.add(select_image_row)
      preferences.add(preview_row)

      select_image_row.tap do |row|
        row.signal_connect('activated') { open_file_dialog }
      end

      preview_row.tap do |row|
        row.child = preview_container

        preview_container.tap do |container|
          container.append(preview_frame)

          preview_frame.tap do |frame|
            frame.child = preview_picture

            preview_picture.tap do |picture|
              picture.add_controller(drop_target)
              picture.add_controller(click_gesture)
            end
          end
        end
      end

      drop_target.tap do |target|
        target.signal_connect('drop') { |_target, value, _x, _y| on_file_dropped(value) }
      end

      click_gesture.tap do |gesture|
        gesture.signal_connect('pressed') { open_file_dialog }
      end

      preset_button.on_select { |path| load_async(path) }

      update_preview
    end
  end

  def on_change(&block)
    @on_change = block
  end

  def image_background = @image_background

  def group
    @group ||= Adwaita::PreferencesGroup.new.tap do |preferences|
      preferences.title = 'Image Background'
    end
  end

  def select_image_row
    @select_image_row ||= Adwaita::ButtonRow.new.tap do |row|
      row.title = 'Select Image'
      row.start_icon_name = 'image-alt-symbolic'
    end
  end

  def preview_row
    @preview_row ||= Adwaita::ActionRow.new.tap do |row|
      row.activatable = false
    end
  end

  def preview_container
    @preview_container ||= Gtk::Box.new(:vertical, 0).tap do |container|
      container.hexpand = true
      container.halign = :center
    end
  end

  def preview_frame
    @preview_frame ||= Gtk::Frame.new.tap do |frame|
      frame.margin_top = 8
      frame.margin_bottom = 8
    end
  end

  def preview_picture
    @preview_picture ||= Gtk::Picture.new.tap do |picture|
      picture.content_fit = :cover
      picture.set_size_request(PREVIEW_WIDTH, PREVIEW_HEIGHT)
    end
  end

  def preset_button = @preset_button ||= ImagePresetButton.new(logger: @logger)

  def drop_target = @drop_target ||= Gtk::DropTarget.new(Gio::File.gtype, :copy)

  def click_gesture = @click_gesture ||= Gtk::GestureClick.new

  def file_dialog
    @file_dialog ||= Gtk::FileDialog.new.tap do |dialog|
      dialog.title = 'Select an Image'
      dialog.modal = true
      dialog.filters = filter_list
    end
  end

  def filter_list
    @filter_list ||= Gio::ListStore.new(Gtk::FileFilter.gtype).tap do |store|
      store.append(image_filter)
    end
  end

  def image_filter
    @image_filter ||= Gtk::FileFilter.new.tap do |filter|
      filter.name = 'Supported Image Formats'
      MIME_TYPES.each { |mime_type| filter.add_mime_type(mime_type) }
    end
  end

  private

    def open_file_dialog
      file_dialog.open(group.root, nil) do |dialog, result, _data|
        chosen_file(dialog, result).then do |file|
          if file&.path
            load_async(file.path)
          end
        end
      end
    end

    # A cancelled chooser raises, which is the binding's way of saying the
    # dialog was dismissed.
    def chosen_file(dialog, result)
      dialog.open_finish(result)
    rescue StandardError
      nil
    end

    def on_file_dropped(file)
      file.path.then do |path|
        if path
          load_async(path)
          true
        else
          false
        end
      end
    end

    # Decoding happens off the main loop, as upstream does, because a 4K
    # wallpaper takes long enough to show as a stutter in the sidebar.
    def load_async(path)
      Thread.new do
        @image_background.load_image(path)
        GLib::Idle.add do
          on_image_loaded
          false
        end
      end
    end

    def on_image_loaded
      update_preview
      @image_background.save_image_copy_async

      if @on_change
        @on_change.call(@image_background)
      end
    end

    def update_preview
      if @image_background.image
        preview_picture.pixbuf = preview_pixbuf(@image_background.image)
      else
        preview_picture.paintable = nil
      end
    end

    # Capped at 400px wide; the preview box is 250 and the extra headroom is
    # what upstream leaves for a HiDPI scale factor.
    def preview_pixbuf(pixbuf)
      if pixbuf.width > PREVIEW_MAX_WIDTH
        (PREVIEW_MAX_WIDTH.to_f / pixbuf.width).then do |ratio|
          pixbuf.scale_simple(PREVIEW_MAX_WIDTH, (pixbuf.height * ratio).to_i, :bilinear)
        end
      else
        pixbuf
      end
    end
end
