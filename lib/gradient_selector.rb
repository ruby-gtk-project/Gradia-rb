# frozen_string_literal: true

require 'adwaita'
require_relative 'angle_selector'
require_relative 'gradient'
require_relative 'gradient_editor'
require_relative 'gradient_step_dialog'
require_relative 'preset_button'

# GradientSelector is the gradient page of the background sidebar: the angle
# dial and its entry, a linear/radial/conic toggle group, the draggable
# gradient bar, and the preset and step-dialog buttons in the group header.
#
# Ported from gradia/graphics/gradient_selector.py and
# data/ui/selectors/gradient_selector.blp. Upstream wires the pieces to each
# other through GObject properties the blueprint binds (`notify::angle`,
# `notify::active-name`, the editor's back-reference to the selector); the port
# passes callbacks instead, so the editor reports a new selection rather than
# reaching into the selector's revealers itself.
class GradientSelector
  MODES = [
    ['linear', 'linear-symbolic', 'Linear'],
    ['radial', 'radial-symbolic', 'Radial'],
    ['conic', 'conic-symbolic', 'Conic'],
  ].freeze

  RADIAL_OPACITY = 0.30

  def initialize(gradient_background, &on_change)
    @gradient_background = gradient_background
    @on_change = on_change
    @updating_entry = false
  end

  def build
    group.tap do |preferences|
      preferences.header_suffix = header_box
      preferences.add(preview_row)

      header_box.tap do |box|
        box.append(step_dialog_button.build)
        box.append(preset_button.build)
      end

      preview_row.tap { |row| row.child = preview_box }

      preview_box.tap do |box|
        box.append(controls_box)
        box.append(gradient_editor.build)

        controls_box.tap do |controls|
          controls.append(angle_selector.build)
          controls.append(right_column)
        end

        right_column.tap do |column|
          column.append(type_row)
          column.append(entry_row)

          type_row.tap { |row| row.append(type_group) }

          entry_row.tap do |row|
            row.append(angle_entry_box)
            row.append(button_revealer)

            angle_entry_box.tap { |entry_box| entry_box.append(angle_entry) }

            button_revealer.tap do |revealer|
              revealer.child = step_box

              step_box.tap do |box|
                box.append(step_label)
                box.append(remove_button_revealer)

                remove_button_revealer.tap { |reveal| reveal.child = remove_button }
              end
            end
          end
        end
      end

      angle_entry.signal_connect('activate') { |entry| on_angle_entry_activate(entry) }
      remove_button.signal_connect('clicked') { gradient_editor.remove_selected_button }
      type_group.signal_connect('notify::active-name') { on_type_changed }

      angle_selector.on_angle_changed { |angle| on_angle_set(angle) }
      angle_selector.on_angle_update { |angle| update_angle_entry(angle) }
      gradient_editor.on_gradient_change { notify_change }
      gradient_editor.on_selection_change { |button| on_selection_changed(button) }
      preset_button.on_select { |gradient| apply_gradient(gradient) }
      step_dialog_button.on_apply { |gradient| apply_gradient(gradient) }

      apply_widget_properties(@gradient_background.gradient)
      step_dialog_button.gradient = @gradient_background.gradient
    end
  end

  def on_change(&block)
    @on_change = block
  end

  def gradient_background = @gradient_background

  def group
    @group ||= Adwaita::PreferencesGroup.new.tap do |preferences|
      preferences.title = 'Gradient Background'
    end
  end

  def header_box = @header_box ||= Gtk::Box.new(:horizontal, 0)

  def preview_row = @preview_row ||= Adwaita::ActionRow.new

  def preview_box
    @preview_box ||= Gtk::Box.new(:vertical, 12).tap do |box|
      box.valign = :center
      box.halign = :center
      box.height_request = 165
      box.vexpand = true
    end
  end

  def controls_box
    @controls_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
      box.margin_top = 5
      box.height_request = 100
    end
  end

  def right_column
    @right_column ||= Gtk::Box.new(:vertical, 0).tap do |column|
      column.set_size_request(160, 100)
    end
  end

  def type_row
    @type_row ||= Gtk::Box.new(:horizontal, 0).tap do |row|
      row.set_size_request(160, 50)
    end
  end

  def type_group
    @type_group ||= Adwaita::ToggleGroup.new.tap do |group|
      group.valign = :center
      group.width_request = 160

      MODES.each do |(name, icon_name, tooltip)|
        group.add(
          Adwaita::Toggle.new.tap do |toggle|
            toggle.name = name
            toggle.icon_name = icon_name
            toggle.tooltip = tooltip
          end,
        )
      end

      group.active_name = 'linear'
    end
  end

  def entry_row
    @entry_row ||= Gtk::Box.new(:horizontal, 0).tap do |row|
      row.set_size_request(160, 50)
    end
  end

  def angle_entry_box
    @angle_entry_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
      box.set_size_request(60, 50)
    end
  end

  def angle_entry
    @angle_entry ||= Gtk::Entry.new.tap do |entry|
      entry.valign = :center
      entry.text = '0°'
      entry.max_length = 4
      entry.halign = :start
      entry.margin_end = 10
      entry.xalign = 0.5
      entry.add_css_class('heading')
      entry.add_css_class('angle-entry')
      entry.add_css_class('view')
    end
  end

  def button_revealer
    @button_revealer ||= Gtk::Revealer.new.tap do |revealer|
      revealer.reveal_child = false
      revealer.transition_type = :crossfade
      revealer.transition_duration = 300
    end
  end

  def step_box
    @step_box ||= Gtk::Box.new(:horizontal, 12).tap do |box|
      box.set_size_request(100, 50)
      box.valign = :center
    end
  end

  def step_label
    @step_label ||= Gtk::Label.new('100%').tap do |label|
      label.width_request = 40
      label.add_css_class('heading')
    end
  end

  def remove_button_revealer
    @remove_button_revealer ||= Gtk::Revealer.new.tap do |revealer|
      revealer.reveal_child = false
      revealer.transition_type = :crossfade
      revealer.transition_duration = 300
    end
  end

  def remove_button
    @remove_button ||= Gtk::Button.new.tap do |button|
      button.valign = :center
      button.tooltip_text = 'Remove Selected Color Step'
      button.icon_name = 'user-trash-symbolic'
      button.add_css_class('destructive-action')
      button.add_css_class('circular')
    end
  end

  def angle_selector = @angle_selector ||= AngleSelector.new(angle: @gradient_background.gradient.angle)

  def gradient_editor = @gradient_editor ||= GradientEditor.new

  def preset_button = @preset_button ||= GradientPresetButton.new

  def step_dialog_button = @step_dialog_button ||= GradientStepDialogButton.new

  private

    # Everything the sidebar reads back comes from the widgets, not from a
    # cached gradient, so a change in any one of them produces one new
    # Gradient — which is how upstream's _notify works too.
    def notify_change
      Gradient.new(
        mode:  type_group.active_name,
        steps: gradient_editor.gradient_data,
        angle: angle_selector.angle,
      ).tap do |gradient|
        @gradient_background.gradient = gradient
        step_dialog_button.gradient = gradient

        if @on_change
          @on_change.call(@gradient_background)
        end
      end
    end

    def apply_gradient(gradient)
      apply_widget_properties(gradient)
      notify_change
    end

    def apply_widget_properties(gradient)
      angle_selector.angle = gradient.angle
      update_angle_entry(gradient.angle)
      type_group.active_name = gradient.mode
      gradient_editor.gradient_data = gradient.steps
    end

    def on_angle_set(angle)
      update_angle_entry(angle)
      notify_change
    end

    def on_angle_entry_activate(entry)
      unless @updating_entry
        if set_angle_from_text(entry.text)
          notify_change
        end
      end
    end

    # "135°" and "135" both parse; anything else puts the dial's angle back in
    # the box rather than leaving unparsable text sitting there.
    def set_angle_from_text(text)
      Float(text.to_s.delete('°').strip).then do |angle|
        angle.clamp(0, 360).tap do |clamped|
          angle_selector.angle = clamped
          update_angle_entry(clamped)
        end
      end
      true
    rescue ArgumentError, TypeError
      update_angle_entry(angle_selector.angle)
      false
    end

    def update_angle_entry(angle)
      unless @updating_entry
        @updating_entry = true
        angle_entry.text = format('%d°', angle.round)
        @updating_entry = false
      end
    end

    # A radial gradient has no angle, so the dial and the entry go insensitive
    # and the dial fades out.
    def on_type_changed
      (type_group.active_name == 'radial').then do |radial|
        angle_selector.drawing_area.sensitive = !radial
        angle_entry.sensitive = !radial

        if radial
          angle_selector.drawing_area.opacity = RADIAL_OPACITY
        else
          angle_selector.drawing_area.opacity = 1
        end
      end

      notify_change
    end

    # The selected stop's position shows next to the entry, and the remove
    # button appears only while there is more than the two end stops.
    def on_selection_changed(button)
      if button
        step_label.label = format('%d%%', (GradientEditor.scale_correction(button.step) * 100).round)
        button_revealer.reveal_child = true
        remove_button_revealer.reveal_child = gradient_editor.stop_count > 2
      else
        button_revealer.reveal_child = false
      end
    end
end
