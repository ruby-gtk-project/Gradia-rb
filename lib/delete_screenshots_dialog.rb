# frozen_string_literal: true

require 'adwaita'

# DeleteScreenshotsDialog is the "Trash Screenshots?" sheet: it lists the files
# about to go and asks once. Asking about nothing is not a dialog but a toast.
#
# Ported from gradia/ui/dialog/delete_screenshots_dialog.py. Upstream builds a
# fresh Adw.AlertDialog per invocation because the file list and the singular
# or plural wording change every time, and the port does the same. The answer
# arrives through the dialog's `response` signal rather than
# Adw.AlertDialog.choose, whose Ruby binding hands back a Gio::Task instead of
# the response id.
class DeleteScreenshotsDialog
  SINGULAR = ['Trash Screenshot?', 'Are you sure you want to trash the following file?'].freeze
  PLURAL = ['Trash Screenshots?', 'Are you sure you want to trash the following files?'].freeze
  EMPTY_MESSAGE = 'No screenshots to delete'
  DELETED_SINGULAR = 'Screenshot moved to trash'
  DELETED_PLURAL = 'Screenshots moved to trash'

  def initialize(parent)
    @parent = parent
  end

  def show(screenshot_uris, on_delete:, on_notify:)
    if screenshot_uris.empty?
      on_notify.call(EMPTY_MESSAGE)
    else
      present(screenshot_uris, on_delete, on_notify)
    end
  end

  private

    def present(screenshot_uris, on_delete, on_notify)
      dialog(screenshot_uris).tap do |sheet|
        sheet.signal_connect('response') do |_sheet, response|
          if response == 'delete'
            on_delete.call
            on_notify.call(deleted_message(screenshot_uris.length))
          end
        end
        sheet.present(@parent)
      end
    end

    def dialog(screenshot_uris)
      dialog_text(screenshot_uris.length).then do |(heading, body)|
        Adwaita::AlertDialog.new.tap do |sheet|
          sheet.heading = heading
          sheet.body = body
          sheet.close_response = 'cancel'
          sheet.extra_child = file_list(screenshot_uris)
          sheet.add_response('cancel', 'Cancel')
          sheet.add_response('delete', 'Trash')
          sheet.set_response_appearance('delete', :destructive)
        end
      end
    end

    def file_list(screenshot_uris)
      Gtk::ListBox.new.tap do |list|
        list.selection_mode = :none
        list.add_css_class('boxed-list')
        screenshot_uris.each { |uri| list.append(file_row(basename_of(uri))) }
      end
    end

    def file_row(filename)
      Adwaita::ActionRow.new.tap do |row|
        row.child = file_label(filename)
      end
    end

    def file_label(filename)
      Gtk::Label.new(filename).tap do |label|
        label.xalign = 0
        label.wrap = true
        label.margin_top = 6
        label.margin_bottom = 6
        label.margin_start = 12
        label.margin_end = 12
      end
    end

    # Upstream parses the URI and takes the display basename of its path; a
    # Gio::File does both in one step.
    def basename_of(uri) = Gio::File.new_for_uri(uri.to_s).basename

    def dialog_text(count)
      if count == 1
        SINGULAR
      else
        PLURAL
      end
    end

    def deleted_message(count)
      if count == 1
        DELETED_SINGULAR
      else
        DELETED_PLURAL
      end
    end
end
