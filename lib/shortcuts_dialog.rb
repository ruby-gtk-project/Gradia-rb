# frozen_string_literal: true

require 'adwaita'

# ShortcutsDialog is the keyboard-shortcuts window: five sections listing every
# accelerator the app binds.
#
# Ported from gradia/ui/ui_parts.py (the ShortcutsDialog class). Upstream keeps
# a Gtk.ShortcutsWindow fallback for libadwaita older than 1.8, which is where
# Adw.ShortcutsDialog arrives; the Ruby bindings ship libadwaita 1.9, and
# Gtk.ShortcutsWindow is deprecated from GTK 4.18, so only the Adwaita path is
# ported — the fallback could never be the one taken here.
class ShortcutsDialog
  SECTIONS = {
    'File Actions' => {
      'Open Image'              => '<Ctrl>O',
      'Take a Screenshot'       => '<Ctrl>A',
      'Save to File'            => '<Ctrl>S',
      'Copy Image to Clipboard' => '<Ctrl>C',
      'Paste From Clipboard'    => '<Ctrl>V',
      'Share Image'             => '<Ctrl>M',
    },
    'Annotations'  => {
      'Undo'           => '<Ctrl>Z',
      'Redo'           => '<Ctrl><Shift>Z',
      'Erase Selected' => 'Delete',
      'Select'         => '0 S',
      'Pen'            => '1 P',
      'Text'           => '2 T',
      'Line'           => '3 L',
      'Arrow'          => '4 A',
      'Rectangle'      => '5 R',
      'Oval'           => '6 O',
      'Highlighter'    => '7 H',
      'Censor'         => '8 C',
      'Number'         => '9 N',
    },
    'Cropping'     => {
      'Toggle Crop Mode' => '<Ctrl>R',
      'Reset Crop'       => '<Ctrl><Shift>R',
    },
    'Zooming'      => {
      'Zoom In'    => '<Ctrl>plus',
      'Zoom Out'   => '<Ctrl>minus',
      'Reset Zoom' => '<Ctrl>0',
      'Pan Left'   => '<Ctrl>Left',
      'Pan Right'  => '<Ctrl>Right',
      'Pan Up'     => '<Ctrl>Up',
      'Pan Down'   => '<Ctrl>Down',
    },
    'General'      => {
      'Toggle Sidebar'           => 'F9',
      'Keyboard Shortcuts'       => '<Ctrl>question',
      'Preferences'              => '<Ctrl>comma',
      'Open Source Snippets'     => '<Ctrl>P',
      'Delete Taken Screenshots' => '<Ctrl><Shift>D',
    },
  }.freeze

  def initialize(parent = nil)
    @parent = parent
  end

  def show
    dialog.present(@parent)
  end

  def parent=(parent)
    @parent = parent
  end

  def dialog
    @dialog ||= Adwaita::ShortcutsDialog.new.tap do |shortcuts|
      sections.each { |section| shortcuts.add(section) }
    end
  end

  def sections
    @sections ||= SECTIONS.map do |title, shortcuts|
      Adwaita::ShortcutsSection.new.tap do |section|
        section.title = title
        shortcuts.each { |(label, accelerator)| section.add(Adwaita::ShortcutsItem.new(label, accelerator)) }
      end
    end
  end
end
