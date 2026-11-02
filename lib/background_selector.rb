# frozen_string_literal: true

require 'adwaita'
require_relative 'gradient'
require_relative 'gradient_selector'
require_relative 'image_background'
require_relative 'image_selector'
require_relative 'logger'
require_relative 'settings'
require_relative 'solid_background'
require_relative 'solid_selector'
require_relative 'toggle_group'

# BackgroundSelector is the top of the sidebar: the None / Solid / Gradient /
# Image toggle group, and under it the page belonging to whichever mode is
# chosen. Picking "None" slides the page away instead of showing an empty one.
#
# Ported from gradia/ui/background_selector.py and
# data/ui/background_selector.blp. The three backgrounds are built up front and
# kept, as upstream does, so switching modes comes back to the colour, gradient
# and picture the mode was left on; only the mode itself and the two JSON
# states are written to the settings.
class BackgroundSelector
  MODES = %w[none solid gradient image].freeze
  DEFAULT_MODE = 'gradient'

  def initialize(settings: nil, logger: GradiaLogger.new, &on_change)
    @settings = settings || Settings.new
    @logger = logger
    @on_change = on_change
    @on_mode_change = nil
    @current_mode = initial_mode
  end

  def build
    bin.tap do |root|
      root.child = container

      container.tap do |box|
        box.append(separator)
        box.append(toggle_group.build)
        box.append(stack_revealer)

        stack_revealer.tap do |revealer|
          revealer.child = stack

          stack.tap do |pages|
            pages.add_named(solid_selector.build, 'solid')
            pages.add_named(gradient_selector.build, 'gradient')
            pages.add_named(image_selector.build, 'image')
          end
        end
      end

      toggle_group.active_name = @current_mode
      toggle_group.on_change { |name| on_mode_changed(name) }

      solid_selector.on_change { |solid| on_solid_changed(solid) }
      gradient_selector.on_change { |gradient| on_gradient_changed(gradient) }
      image_selector.on_change { on_image_changed }

      unless @current_mode == 'none'
        stack.visible_child_name = @current_mode
      end

      update_revealer_visibility
    end
  end

  def on_change(&block)
    @on_change = block
  end

  # The sidebar also wants to know which mode is live, so it can grey out the
  # rows a bare image has no use for. Setting the callback reports the current
  # mode straight away, as upstream's set_current_mode_callback does.
  def on_mode_change(&block)
    @on_mode_change = block
    notify_current
  end

  def current_mode = @current_mode

  def current_background
    case @current_mode
    when 'solid' then solid
    when 'gradient' then gradient
    when 'image' then image
    end
  end

  def solid = @solid ||= SolidBackground.from_json(@settings.solid_state.to_s)

  def gradient = @gradient ||= GradientBackground.from_json(@settings.gradient_state.to_s)

  def image = @image ||= ImageBackground.new(logger: @logger)

  def bin = @bin ||= Adwaita::Bin.new

  def container = @container ||= Gtk::Box.new(:vertical, 0)

  def separator
    @separator ||= Gtk::Separator.new(:horizontal).tap do |line|
      line.margin_bottom = 12
    end
  end

  def toggle_group = @toggle_group ||= ToggleGroup.new

  def stack_revealer
    @stack_revealer ||= Gtk::Revealer.new.tap do |revealer|
      revealer.transition_type = :slide_up
      revealer.transition_duration = 250
    end
  end

  def stack
    @stack ||= Gtk::Stack.new.tap do |pages|
      pages.margin_top = 12
      pages.transition_type = :crossfade
      pages.transition_duration = 250
      pages.hexpand = true
      pages.valign = :start
    end
  end

  def solid_selector = @solid_selector ||= SolidSelector.new(solid)

  def gradient_selector = @gradient_selector ||= GradientSelector.new(gradient)

  def image_selector = @image_selector ||= ImageSelector.new(image, logger: @logger)

  private

    def initial_mode
      @settings.background_mode.then do |mode|
        if MODES.include?(mode)
          mode
        else
          DEFAULT_MODE
        end
      end
    end

    def on_mode_changed(name)
      if MODES.include?(name) && name != @current_mode
        @current_mode = name
        @settings.background_mode = name

        unless name == 'none'
          stack.visible_child_name = name
        end

        update_revealer_visibility
        notify_current
      end
    end

    def on_gradient_changed(background)
      @settings.gradient_state = background.to_json
      if @current_mode == 'gradient'
        notify_current
      end
    end

    def on_solid_changed(background)
      @settings.solid_state = background.to_json
      if @current_mode == 'solid'
        notify_current
      end
    end

    def on_image_changed
      if @current_mode == 'image'
        notify_current
      end
    end

    # The revealer clips its child while it is sliding, otherwise the gradient
    # editor's stop buttons — which hang outside the page — would be cut off;
    # the overflow only opens up once the slide has finished, which is what
    # upstream's 300ms timeout is for.
    def update_revealer_visibility
      (@current_mode != 'none').then do |reveal|
        stack_revealer.child_revealed?.then do |already_revealed|
          stack_revealer.reveal_child = reveal
          set_overflow(reveal, already_revealed)
        end
      end
    end

    def set_overflow(reveal, already_revealed)
      if reveal && already_revealed
        stack_revealer.overflow = :visible
      elsif reveal
        GLib::Timeout.add(stack_revealer.transition_duration + 50) do
          stack_revealer.overflow = :visible
          false
        end
      else
        stack_revealer.overflow = :hidden
      end
    end

    def notify_current
      if @on_change
        @on_change.call(current_background)
      end

      if @on_mode_change
        @on_mode_change.call(@current_mode)
      end
    end
end
