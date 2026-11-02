# frozen_string_literal: true

require 'adwaita'
require_relative 'settings'

# ConfirmCloseDialog is the "Close Gradia?" sheet: Cancel, Copy or Close, plus
# a "Don't Ask Again" checkbox that writes the exit method back to the
# settings.
#
# Ported from gradia/ui/dialog/confirm_close_dialog.py and
# data/ui/confirm_close_dialog.blp. Upstream asks for the answer with
# Adw.AlertDialog.choose, whose Ruby binding reports the response through a
# Gio::Task the port would have to unwrap; the `response` signal the same
# dialog emits carries the response id directly, so the port listens for that.
class ConfirmCloseDialog
  HEADING = 'Close Gradia?'
  BODY = 'Are you sure you want to exit? All unsaved changes will be lost.'

  def initialize(parent, settings: nil)
    @parent = parent
    @settings = settings || Settings.new
  end

  def build
    dialog.tap do |sheet|
      sheet.extra_child = list_box

      list_box.tap do |list|
        list.append(dont_ask_row)

        dont_ask_row.tap do |row|
          row.add_prefix(dont_ask_check_button)
          row.activatable_widget = dont_ask_check_button
        end

        dont_ask_check_button.tap do |check|
          check.active = @settings.exit_method == 'none'
          check.signal_connect('toggled') { |button| on_dont_ask_toggled(button) }
        end
      end

      sheet.signal_connect('response') { |_sheet, response| on_response(response) }
    end
  end

  # The window hands in what to do for the two acting responses each time it
  # asks, because what "Close" means depends on how the window got here.
  def show(on_confirm:, on_copy:)
    @on_confirm = on_confirm
    @on_copy = on_copy
    dialog.present(@parent)
  end

  def dialog
    @dialog ||= Adwaita::AlertDialog.new.tap do |sheet|
      sheet.heading = HEADING
      sheet.body = BODY
      sheet.close_response = 'cancel'
      sheet.prefer_wide_layout = true
      sheet.add_response('cancel', 'Cancel')
      sheet.add_response('copy', 'Copy')
      sheet.add_response('close', 'Close')
      sheet.set_response_appearance('close', :destructive)
    end
  end

  def list_box
    @list_box ||= Gtk::ListBox.new.tap do |list|
      list.selection_mode = :none
      list.add_css_class('boxed-list')
    end
  end

  def dont_ask_row
    @dont_ask_row ||= Adwaita::ActionRow.new.tap do |row|
      row.title = "Don't Ask Again"
    end
  end

  def dont_ask_check_button
    @dont_ask_check_button ||= Gtk::CheckButton.new.tap do |check|
      check.valign = :center
    end
  end

  private

    def on_dont_ask_toggled(button)
      if button.active?
        @settings.exit_method = 'none'
      else
        @settings.exit_method = 'confirm'
      end
    end

    def on_response(response)
      case response
      when 'close' then call(@on_confirm)
      when 'copy' then call(@on_copy)
      end
    end

    def call(callback)
      if callback
        callback.call
      end
    end
end
