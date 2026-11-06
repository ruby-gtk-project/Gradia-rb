# frozen_string_literal: true

require 'gtk4'

# FontDropdown is a vertical box wrapping a single Gtk::DropDown of every
# family the system's Pango font map knows, sorted, each row and the
# collapsed selector rendered in that family's own face.
#
# Ported from gradia/ui/widget/font_dropdown.py. Upstream subclasses
# Gtk.Box and publishes the choice as a `font-changed` GObject signal plus a
# `selected-font` property; a Ruby class cannot register either on a boxed
# Gtk type, so the choice is published as a plain reader plus an `on_change`
# callback.
class FontDropdown
  def initialize(&on_change)
    @on_change = on_change
    @selected_font = nil
    @updating = false
  end

  def build
    box.tap do |b|
      b.append(dropdown)
    end
  end

  def on_change(&block)
    @on_change = block
  end

  attr_reader :selected_font

  def selected_font=(font_name)
    if fonts.include?(font_name) && @selected_font != font_name
      @selected_font = font_name

      @updating = true
      dropdown.selected = fonts.index(font_name)
      @updating = false
    end
  end

  def box = @box ||= Gtk::Box.new(:vertical, 6)

  def dropdown
    @dropdown ||= Gtk::DropDown.new.tap do |drop|
      drop.model = font_list
      drop.vexpand = true
      drop.set_list_factory(list_factory)
      drop.factory = selected_factory
      drop.signal_connect('notify::selected') { on_selected(drop) }
    end
  end

  def font_list
    @font_list ||= Gtk::StringList.new.tap do |list|
      fonts.each { |font| list.append(font) }
    end
  end

  # Every family the default Pango font map knows, sorted by name — upstream's
  # _get_available_fonts.
  def fonts
    @fonts ||= Gtk::Label.new.pango_context.font_map.families.map(&:name).sort
  end

  def list_factory
    @list_factory ||= Gtk::SignalListItemFactory.new.tap do |factory|
      factory.signal_connect('setup') { |_factory, item| item.child = row_label }
      factory.signal_connect('bind') { |_factory, item| bind_row(item) }
    end
  end

  def selected_factory
    @selected_factory ||= Gtk::SignalListItemFactory.new.tap do |factory|
      factory.signal_connect('setup') { |_factory, item| item.child = selected_label }
      factory.signal_connect('bind') { |_factory, item| bind_row(item) }
    end
  end

  private

    def row_label
      Gtk::Label.new.tap do |label|
        label.halign = :start
        label.xalign = 0
        label.ellipsize = :none
      end
    end

    def selected_label
      Gtk::Label.new.tap do |label|
        label.halign = :start
        label.xalign = 0
        label.ellipsize = :end
        label.max_width_chars = 20
      end
    end

    def bind_row(item)
      font_name = item.item.string
      item.child.tap do |label|
        label.text = font_name
        label.attributes = Pango::AttrList.new.tap do |attrs|
          attrs.insert(Pango::AttrFontDesc.new(Pango::FontDescription.new("#{font_name} 12")))
        end
      end
    end

    def on_selected(dropdown)
      unless @updating
        index = dropdown.selected
        if index >= 0 && index < fonts.length
          @selected_font = fonts[index]

          if @on_change
            @on_change.call(@selected_font)
          end
        end
      end
    end
end
