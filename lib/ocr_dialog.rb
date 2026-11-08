# frozen_string_literal: true

require 'adwaita'
require_relative 'ocr'
require_relative 'clipboard'
require_relative 'logger'

# OCRDialog runs text recognition over a loaded image and shows the result:
# a spinner while Tesseract runs, the extracted text in an editable view once
# it is done, or a status page when the image carried no recognisable text.
# A menu button on the header bar switches which installed language model the
# extraction uses, re-running it on every switch.
#
# Ported from gradia/ui/dialog/ocr_dialog.py. Upstream is a Gtk.Template over
# data/ui/ocr_dialog.ui; this port builds the same widget tree declaratively,
# the house pattern for every dialog in this port. Upstream also registers a
# stateful `ocr.select_language` action so the menu can check the active
# entry; the Ruby binding's `Gio::SimpleAction` has no `new_stateful`
# constructor, so the port tracks the active language as a plain instance
# variable and drives the menu button's label from it instead, which is the
# same information the checkmark would have shown.
class OCRDialog
  def initialize(image_path, auto_copy: false, ocr: nil, logger: GradiaLogger.new)
    @image_path = image_path
    @auto_copy = auto_copy
    @ocr = ocr || OCR.new(logger: logger)
    @logger = logger
    @primary_lang = @ocr.get_current_model
  end

  def build
    dialog.tap do |sheet|
      sheet.child = toast_overlay

      toast_overlay.tap do |overlay|
        overlay.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = stack

          header_bar.tap do |bar|
            bar.title_widget = window_title
            bar.pack_end(copy_button)
            bar.pack_end(language_button)

            copy_button.tap do |button|
              button.signal_connect('clicked') { copy_text }
            end
          end

          stack.tap do |s|
            s.add_named(loading_page, 'loading')
            s.add_named(text_page, 'text')
            s.add_named(no_text_page, 'no-text')
          end
        end
      end
    end

    setup_language_menu
    start_ocr
    dialog
  end

  def present(parent) = dialog.present(parent)

  def dialog
    @dialog ||= Adwaita::Dialog.new.tap do |sheet|
      sheet.content_width = 480
      sheet.content_height = 420
    end
  end

  def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new

  def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

  def header_bar = @header_bar ||= Adwaita::HeaderBar.new

  def window_title
    @window_title ||= Adwaita::WindowTitle.new('Extracted Text', @auto_copy ? '' : @image_path)
  end

  def copy_button
    @copy_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = 'edit-copy-symbolic'
      button.tooltip_text = 'Copy to Clipboard'
    end
  end

  def language_button
    @language_button ||= Gtk::MenuButton.new.tap do |button|
      button.icon_name = 'globe-symbolic'
    end
  end

  def language_menu = @language_menu ||= Gio::Menu.new

  def language_action_group = @language_action_group ||= Gio::SimpleActionGroup.new

  def select_language_action
    @select_language_action ||= Gio::SimpleAction.new('select_language', GLib::VariantType.new('s')).tap do |action|
      action.signal_connect('activate') { |_action, parameter| on_language_selected(parameter.get_string) }
    end
  end

  def stack = @stack ||= Gtk::Stack.new

  def loading_page
    @loading_page ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.valign = :center
      box.halign = :center
      box.append(spinner)
    end
  end

  def spinner
    @spinner ||= Gtk::Spinner.new.tap do |spin|
      spin.spinning = true
      spin.width_request = 32
      spin.height_request = 32
    end
  end

  def text_page
    @text_page ||= Gtk::ScrolledWindow.new.tap do |scroller|
      scroller.hscrollbar_policy = :never
      scroller.vscrollbar_policy = :automatic
      scroller.child = text_view
    end
  end

  def text_view
    @text_view ||= Gtk::TextView.new.tap do |view|
      view.editable = false
      view.wrap_mode = :word_char
      view.margin_top = 12
      view.margin_bottom = 12
      view.margin_start = 12
      view.margin_end = 12
    end
  end

  def no_text_page
    @no_text_page ||= Adwaita::StatusPage.new.tap do |page|
      page.icon_name = 'text-x-generic-symbolic'
      page.title = 'No Text Found'
      page.description = 'This image does not contain any recognisable text.'
    end
  end

  def text = text_view.buffer.text

  private

    def setup_language_menu
      language_menu.remove_all

      installed = @ocr.get_installed_models

      @ocr.get_downloadable_models.each do |model|
        if installed.include?(model.code)
          language_menu.append(model.name, "ocr.select_language::#{model.code}")

          if model.code == @primary_lang
            language_button.label = model.name
          end
        end
      end

      language_button.menu_model = language_menu

      language_action_group.tap do |group|
        group.add_action(select_language_action)
      end

      dialog.insert_action_group('ocr', language_action_group)
    end

    def on_language_selected(lang_code)
      @primary_lang = lang_code

      @ocr.get_downloadable_models.each do |model|
        if model.code == lang_code
          language_button.label = model.name
        end
      end

      start_ocr
    end

    def start_ocr
      stack.visible_child_name = 'loading'

      Thread.new do
        extracted = begin
          @ocr.extract_text(@image_path, @primary_lang)
        rescue StandardError => error
          @logger.error("OCR failed: #{error}")
          nil
        end

        GLib::Idle.add { display_text(extracted) }
      end
    end

    def display_text(extracted)
      text_view.buffer.text = extracted.to_s

      if extracted && !extracted.strip.empty?
        stack.visible_child_name = 'text'

        if @auto_copy
          copy_text
        end
      else
        stack.visible_child_name = 'no-text'
      end

      false
    end

    def copy_text
      extracted = text_view.buffer.text

      unless extracted.strip.empty?
        Clipboard.copy_text_to_clipboard(extracted)
        toast_overlay.add_toast(Adwaita::Toast.new('Copied!').tap { |toast| toast.timeout = 1 })
      end
    end
end
