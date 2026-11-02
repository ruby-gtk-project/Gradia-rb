# frozen_string_literal: true

require 'adwaita'
require_relative 'colors'
require_relative 'gradient'

# GradientStepRow is one row of the step editor: a colour button, a percentage
# spinner and a remove button.
#
# Ported from gradia/ui/widget/gradient_step_dialog_button.py (the
# GradientStepRow class).
class GradientStepRow
  def initialize(position:, color:, on_change: nil, on_remove: nil)
    @position = position
    @color = color
    @on_change = on_change
    @on_remove = on_remove
  end

  def build
    row.tap do |action_row|
      action_row.add_prefix(color_button)
      action_row.add_suffix(controls_box)

      color_button.tap do |button|
        button.signal_connect('color-set') { notify_change }
      end

      controls_box.tap do |box|
        box.append(position_spin_button)
        box.append(remove_button)

        position_spin_button.tap do |spin|
          spin.signal_connect('value-changed') { notify_change }
        end

        remove_button.tap do |button|
          button.signal_connect('clicked') { notify_remove }
        end
      end
    end
  end

  # 0.0–1.0, which is how a Gradient stores a step position.
  def position = position_spin_button.value / 100.0

  def color = Colors.rgb_string(color_button.rgba)

  def can_remove=(value)
    remove_button.sensitive = value
  end

  def row = @row ||= Adwaita::ActionRow.new

  def color_button
    @color_button ||= Gtk::ColorButton.new.tap do |button|
      button.valign = :center
      button.rgba = Colors.hex_to_rgba(step_hex)
    end
  end

  def position_spin_button
    @position_spin_button ||= Gtk::SpinButton.new(position_adjustment, 1, 1).tap do |spin|
      spin.value = @position * 100
    end
  end

  def position_adjustment
    @position_adjustment ||= Gtk::Adjustment.new(
      @position * 100,
      0,
      100,
      1,
      10,
      0,
    )
  end

  def controls_box
    @controls_box ||= Gtk::Box.new(:horizontal, 6).tap do |box|
      box.valign = :center
    end
  end

  def remove_button
    @remove_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = 'user-trash-symbolic'
      button.add_css_class('destructive-action')
    end
  end

  private

    # The step colours are stored as "rgb(r,g,b)" strings, which is not
    # something Gdk::RGBA.parse accepts, so they go through Colors first.
    def step_hex
      Colors.parse_rgb_string(@color).then do |(red, green, blue)|
        format(
          '#%02x%02x%02x',
          red,
          green,
          blue,
        )
      end
    end

    def notify_change
      if @on_change
        @on_change.call
      end
    end

    def notify_remove
      if @on_remove
        @on_remove.call(self)
      end
    end
end

# GradientStepDialog is the "Edit Gradient Steps" sheet: a live preview of the
# gradient over a list of up to five step rows.
#
# Ported from gradia/ui/widget/gradient_step_dialog_button.py (the
# CssGradientDialog class) and data/ui/gradient_step_dialog.blp. Upstream hands
# the edited gradient back when the dialog closes rather than on an OK button,
# and only when the CSS actually differs from what it opened with; the port
# keeps both, including the minimum-spacing pass that runs just before.
class GradientStepDialog
  MAX_STEPS = 5
  MIN_GAP = 0.18
  NEW_STEP_COLOR = 'rgb(128,128,128)'
  NEW_STEP_POSITION = 0.5

  def initialize(&on_apply)
    @on_apply = on_apply
    @rows = []
  end

  def build
    dialog.tap do |sheet|
      sheet.child = toolbar_view

      toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.content = scrolled_window
      end

      scrolled_window.tap do |scroller|
        scroller.child = clamp

        clamp.tap do |area|
          area.child = main_box

          main_box.tap do |box|
            box.append(preview_frame)
            box.append(steps_group)

            preview_frame.tap { |frame| frame.child = preview_box }

            steps_group.tap do |group|
              group.header_suffix = add_step_button

              add_step_button.tap do |button|
                button.signal_connect('clicked') { add_step }
              end
            end
          end
        end
      end

      sheet.signal_connect('closed') { on_closed }
    end
  end

  def on_apply(&block)
    @on_apply = block
  end

  def gradient = @gradient

  # Opening the dialog on a gradient refills the rows and the preview, and
  # records what to compare against when it closes.
  def gradient=(value)
    @gradient = value
    @initial_gradient = value
    populate_steps
    update_preview
  end

  def present(parent)
    dialog.present(parent)
  end

  def dialog
    @dialog ||= Adwaita::Dialog.new.tap do |sheet|
      sheet.can_close = true
      sheet.content_width = 400
      sheet.content_height = 420
      sheet.title = 'Edit Gradient Steps'
    end
  end

  def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

  def header_bar
    @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
      bar.show_end_title_buttons = true
    end
  end

  def scrolled_window
    @scrolled_window ||= Gtk::ScrolledWindow.new.tap do |scroller|
      scroller.hscrollbar_policy = :never
      scroller.vscrollbar_policy = :automatic
    end
  end

  def clamp
    @clamp ||= Adwaita::Clamp.new.tap do |area|
      area.maximum_size = 600
      area.tightening_threshold = 400
    end
  end

  def main_box
    @main_box ||= Gtk::Box.new(:vertical, 24).tap do |box|
      box.margin_top = 24
      box.margin_bottom = 24
      box.margin_start = 24
      box.margin_end = 24
    end
  end

  def preview_frame
    @preview_frame ||= Gtk::Frame.new.tap do |frame|
      frame.height_request = 80
      frame.add_css_class('card')
    end
  end

  def preview_box
    @preview_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
      box.height_request = 80
      box.add_css_class('gradient-preview')
    end
  end

  def steps_group
    @steps_group ||= Adwaita::PreferencesGroup.new.tap do |group|
      group.title = 'Gradient Steps'
      group.description = 'You can add up to five steps'
    end
  end

  def add_step_button
    @add_step_button ||= Gtk::Button.new.tap do |button|
      button.label = 'Add Step'
      button.icon_name = 'list-add-symbolic'
      button.add_css_class('suggested-action')
      button.halign = :start
      button.valign = :center
    end
  end

  private

    def populate_steps
      @rows.each { |row| steps_group.remove(row.row) }
      @rows = @gradient.steps.map { |(position, color)| step_row(position, color) }
      @rows.each { |row| steps_group.add(row.build) }
      update_row_sensitivity
      update_add_button_sensitivity
    end

    def step_row(position, color)
      GradientStepRow.new(
        position:  position,
        color:     color,
        on_change: -> { rebuild_gradient },
        on_remove: ->(row) { remove_row(row) },
      )
    end

    def remove_row(row)
      if @rows.length > 2
        steps_group.remove(row.row)
        @rows.delete(row)
        rebuild_gradient
      end
    end

    # Every change re-reads all the rows, so a row's colour and position never
    # have to be written back into the gradient one at a time.
    def rebuild_gradient
      @gradient = Gradient.new(
        mode:  @gradient.mode,
        steps: @rows.map { |row| [row.position, row.color] }.sort_by(&:first),
        angle: @gradient.angle,
      )
      update_preview
      update_row_sensitivity
      update_add_button_sensitivity
    end

    # A new step lands in the first gap wider than 10%, or at the halfway
    # mark when there is none.
    def add_step
      if @rows.length < MAX_STEPS
        @rows.push(step_row(next_position, NEW_STEP_COLOR))
        steps_group.add(@rows.last.build)
        rebuild_gradient
      end
    end

    def next_position
      @rows.map(&:position).sort.each_cons(2) do |(left, right)|
        if (right - left) > 0.1
          break left + ((right - left) / 2)
        end
      end.then do |found|
        if found.is_a?(Float)
          found
        else
          NEW_STEP_POSITION
        end
      end
    end

    def update_row_sensitivity
      (@rows.length > 2).then { |can_remove| @rows.each { |row| row.can_remove = can_remove } }
    end

    def update_add_button_sensitivity
      add_step_button.sensitive = @rows.length < MAX_STEPS
    end

    # Upstream rebuilds a provider on every preview update and leaves the old
    # ones attached; the port keeps one provider and reloads it.
    def update_preview
      if @gradient
        preview_provider.load_from_string(".gradient-preview { background-image: #{@gradient.to_css}; }")
      end
    end

    def preview_provider
      @preview_provider ||= Gtk::CssProvider.new.tap do |provider|
        preview_box.style_context.add_provider(provider, Gtk::StyleProvider::PRIORITY_APPLICATION + 5)
      end
    end

    def on_closed
      if @gradient && @on_apply && changed?
        @gradient = spaced_gradient
        @on_apply.call(@gradient)
      end
    end

    def changed? = @initial_gradient.nil? || @gradient.to_css != @initial_gradient.to_css

    # Steps closer together than MIN_GAP are pushed apart — forwards first,
    # then backwards so the last step never runs off the end.
    def spaced_gradient
      Gradient.new(
        mode:  @gradient.mode,
        steps: spaced_steps(@gradient.steps.sort_by(&:first)),
        angle: @gradient.angle,
      )
    end

    def spaced_steps(steps)
      if steps.length < 2
        steps
      else
        pull_back(push_forward(steps))
      end
    end

    def push_forward(steps)
      steps.drop(1).each_with_object([steps.first]) do |(position, color), adjusted|
        adjusted.last.first.then do |previous|
          if (position - previous) < MIN_GAP
            adjusted.push([[previous + MIN_GAP, 1.0].min, color])
          else
            adjusted.push([position, color])
          end
        end
      end
    end

    def pull_back(steps)
      steps.dup.tap do |adjusted|
        (adjusted.length - 2).downto(0) do |index|
          adjusted[index + 1].first.then do |following|
            if (following - adjusted[index].first) < MIN_GAP
              adjusted[index] = [[0.0, following - MIN_GAP].max, adjusted[index].last]
            end
          end
        end
      end
    end
end

# GradientStepDialogButton is the little edit button in the gradient group's
# header that opens the step dialog.
#
# Ported from gradia/ui/widget/gradient_step_dialog_button.py (the
# GradientStepDialogButton class).
class GradientStepDialogButton
  def initialize(&on_apply)
    @on_apply = on_apply
  end

  def build
    button.tap do |edit|
      edit.signal_connect('clicked') { open_dialog }
    end
  end

  def on_apply(&block)
    @on_apply = block
  end

  def gradient = @gradient

  def gradient=(value)
    @gradient = value
  end

  def button
    @button ||= Gtk::Button.new.tap do |edit|
      edit.icon_name = 'edit-symbolic'
      edit.valign = :center
      edit.tooltip_text = 'Open Step Dialog'
      edit.add_css_class('flat')
    end
  end

  def dialog
    @dialog ||= GradientStepDialog.new { |gradient| on_dialog_apply(gradient) }.tap(&:build)
  end

  private

    # Upstream raises when the button is clicked before a gradient is set; the
    # selector always sets one in its constructor, so the guard only fires for
    # a caller that forgot, and a quiet no-op would hide that.
    def open_dialog
      if @gradient.nil?
        raise ArgumentError, 'No gradient set; assign one before opening the step dialog'
      end

      dialog.gradient = @gradient
      dialog.present(button.root)
    end

    def on_dialog_apply(gradient)
      @gradient = gradient
      if @on_apply
        @on_apply.call(gradient)
      end
    end
end
