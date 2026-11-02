# frozen_string_literal: true

require 'adwaita'
require_relative 'colors'

# AngleSelector is the round gradient-angle control: a ring with tick marks at
# the quarter turns and a teardrop handle that is dragged around it, snapping
# to 0, 90, 180 and 270 and holding there until the pointer pulls far enough
# away.
#
# Ported from gradia/ui/widget/angle_selector.py. Upstream subclasses
# Gtk.Widget and paints in `do_snapshot` with Gsk render nodes; the Ruby
# bindings cannot override a widget's snapshot, so the same geometry is drawn
# with Cairo into a Gtk::DrawingArea — including the handle's two offset
# shadows, which upstream gets from Gsk.OutsetShadowNode.
class AngleSelector
  OUTER_RADIUS = 40
  INNER_RADIUS = 37
  HANDLE_SIZE = 20
  HANDLE_RADIUS = 10
  BORDER_WIDTH = 4
  TICK_LENGTH = 4
  TICK_INSET = 8
  TICK_THICKNESS = 1
  EXIT_THRESHOLD = 25
  SNAP_ANGLES = [0, 90, 180, 270].freeze

  attr_reader :angle

  def initialize(angle: 0, &on_angle_changed)
    @angle = angle
    @on_angle_changed = on_angle_changed
    @on_angle_update = nil
    @dragging = false
  end

  def build
    drawing_area.tap do |area|
      area.set_draw_func { |_widget, context, width, height| draw(context, width, height) }
      area.add_controller(drag_gesture)
      area.add_controller(click_gesture)

      drag_gesture.tap do |gesture|
        gesture.signal_connect('drag-begin') { |_g, x, y| on_drag_begin(x, y) }
        gesture.signal_connect('drag-update') { |g, dx, dy| on_drag_update(g, dx, dy) }
        gesture.signal_connect('drag-end') { on_drag_end }
      end

      click_gesture.tap do |gesture|
        gesture.signal_connect('pressed') { |_g, _n_press, x, y| on_click(x, y) }
      end
    end
  end

  def on_angle_changed(&block)
    @on_angle_changed = block
  end

  # Fires for every angle the handle passes through, where on_angle_changed
  # fires once the drag ends. Upstream gets the two from the `angle-changed`
  # signal and the `notify::angle` property notification respectively, and the
  # gradient selector needs both: the entry tracks the handle live, while the
  # gradient is only rebuilt once the handle settles.
  def on_angle_update(&block)
    @on_angle_update = block
  end

  def angle=(degrees)
    set_angle_internal(degrees)
  end

  def angle_radians = @angle * Math::PI / 180.0

  def angle_radians=(radians)
    set_angle_internal((radians * 180.0 / Math::PI) % 360)
  end

  def drawing_area
    @drawing_area ||= Gtk::DrawingArea.new.tap do |area|
      area.set_size_request(100, 100)
      area.can_focus = true
      area.add_css_class('angle-selector')
    end
  end

  def drag_gesture = @drag_gesture ||= Gtk::GestureDrag.new
  def click_gesture = @click_gesture ||= Gtk::GestureClick.new

  private

    def center = [drawing_area.width / 2.0, drawing_area.height / 2.0]

    def handle_position
      center.then do |(cx, cy)|
        ((@angle - 90) * Math::PI / 180.0).then do |radians|
          [cx + (INNER_RADIUS * Math.cos(radians)), cy + (INNER_RADIUS * Math.sin(radians))]
        end
      end
    end

    def point_to_angle(x, y)
      center.then do |(cx, cy)|
        ((Math.atan2(y - cy, x - cx) * 180.0 / Math::PI) + 90) % 360
      end
    end

    # Once the handle has landed on a quarter turn it stays there until the
    # pointer is more than EXIT_THRESHOLD degrees away, which is what makes the
    # snap feel sticky rather than magnetic.
    def snap_to_90_degrees(angle)
      SNAP_ANGLES.find { |snap| @angle == snap }.then do |snap|
        if snap && distance_between(angle, snap) <= EXIT_THRESHOLD
          snap
        else
          angle
        end
      end
    end

    def distance_between(angle, snap)
      (angle - snap).abs.then do |distance|
        if distance > 180
          360 - distance
        else
          distance
        end
      end
    end

    def point_in_handle?(x, y)
      handle_position.then do |(hx, hy)|
        Math.hypot(x - hx, y - hy) <= HANDLE_RADIUS + 5
      end
    end

    def on_click(x, y)
      unless point_in_handle?(x, y)
        set_angle_internal(snap_to_90_degrees(point_to_angle(x, y)))
        emit_angle_changed
      end
    end

    def on_drag_begin(start_x, start_y)
      unless point_in_handle?(start_x, start_y)
        set_angle_internal(snap_to_90_degrees(point_to_angle(start_x, start_y)))
      end

      @dragging = true
      drawing_area.grab_focus
    end

    def on_drag_update(gesture, offset_x, offset_y)
      if @dragging
        gesture.start_point.then do |(start_x, start_y)|
          set_angle_internal(snap_to_90_degrees(point_to_angle(start_x + offset_x, start_y + offset_y)))
        end
      end
    end

    def on_drag_end
      @dragging = false
      emit_angle_changed
    end

    def set_angle_internal(degrees)
      (degrees % 360).then do |wrapped|
        if (@angle - wrapped).abs > 0.5
          @angle = wrapped.round
          drawing_area.queue_draw
          emit_angle_update
        end
      end
    end

    def emit_angle_update
      if @on_angle_update
        @on_angle_update.call(@angle)
      end
    end

    def emit_angle_changed
      if @on_angle_changed
        @on_angle_changed.call(@angle)
      end
    end

    def draw(context, width, height)
      palette.then do |colors|
        [width / 2.0, height / 2.0].then do |(cx, cy)|
          draw_circle_border(
            context,
            cx,
            cy,
            colors[:background],
          )
          draw_90_degree_lines(
            context,
            cx,
            cy,
            colors[:foreground],
          )
          draw_handle(
            context,
            cx,
            cy,
            colors[:handle],
            colors[:shadow],
          )
        end
      end
    end

    # Upstream reads one colour out of the style context and decides the
    # palette from its luminance: a light foreground means a dark theme.
    def palette
      if Colors.light_color_rgba?(drawing_area.style_context.color)
        {
          background: [0.88, 0.88, 0.88, 1],
          foreground: [0.88, 0.88, 0.88, 1],
          handle:     [1, 1, 1, 1],
          shadow:     [0, 0, 0.023],
        }
      else
        {
          background: [0.32, 0.32, 0.33, 1],
          foreground: [0.32, 0.32, 0.33, 1],
          handle:     [0.82, 0.82, 0.82, 1],
          shadow:     [0, 0, 0.023],
        }
      end
    end

    def draw_circle_border(context, cx, cy, color)
      set_color(context, color)
      context.line_width = BORDER_WIDTH
      context.arc(
        cx,
        cy,
        OUTER_RADIUS - (BORDER_WIDTH / 2.0),
        0,
        2 * Math::PI,
      )
      context.stroke
    end

    def draw_90_degree_lines(context, cx, cy, color)
      set_color(context, color)

      SNAP_ANGLES.each do |tick|
        ((tick - 90) * Math::PI / 180.0).then do |radians|
          tick_rect(cx, cy, radians).then do |(x, y, tick_width, tick_height)|
            context.rectangle(
              x,
              y,
              tick_width,
              tick_height,
            )
            context.fill
          end
        end
      end
    end

    # The ticks are axis-aligned rectangles, as upstream's colour nodes are:
    # horizontal for the left and right ticks, vertical for the other two.
    def tick_rect(cx, cy, radians)
      (OUTER_RADIUS - TICK_INSET).then do |outer|
        [outer, outer - TICK_LENGTH].map { |radius| [cx + (radius * Math.cos(radians)), cy + (radius * Math.sin(radians))] }
          .then { |(outer_point, inner_point)| axis_rect(
            cx,
            cy,
            outer_point,
            inner_point,
          ) }
      end
    end

    def axis_rect(cx, cy, outer_point, inner_point)
      if (outer_point[0] - inner_point[0]).abs > (outer_point[1] - inner_point[1]).abs
        [
          [outer_point[0], inner_point[0]].min,
          cy - (TICK_THICKNESS / 2.0),
          (inner_point[0] - outer_point[0]).abs,
          TICK_THICKNESS,
        ]
      else
        [
          cx - (TICK_THICKNESS / 2.0),
          [outer_point[1], inner_point[1]].min,
          TICK_THICKNESS,
          (inner_point[1] - outer_point[1]).abs,
        ]
      end
    end

    # The handle is a rounded square with the corner facing the centre left
    # square, so it reads as a teardrop pointing inwards.
    def draw_handle(context, cx, cy, color, shadow)
      handle_position.then do |(hx, hy)|
        context.save
        context.translate(hx, hy)
        context.rotate((Math.atan2(cy - hy, cx - hx) * 180.0 / Math::PI - 45) * Math::PI / 180.0)
        context.translate(-HANDLE_RADIUS, -HANDLE_RADIUS)

        handle_shadows(context, shadow)
        handle_face(context, color)

        context.restore
      end
    end

    def handle_shadows(context, shadow)
      [[0, 1, 0.1], [0, 4, 0.2]].each do |(dx, dy, alpha)|
        context.save
        context.translate(dx, dy)
        handle_path(context)
        set_color(context, shadow + [alpha])
        context.fill
        context.restore
      end
    end

    def handle_face(context, color)
      handle_path(context)
      set_color(context, color)
      context.fill
    end

    def handle_path(context)
      context.new_sub_path
      context.arc(
        HANDLE_RADIUS,
        HANDLE_RADIUS,
        HANDLE_RADIUS,
        Math::PI,
        3 * Math::PI / 2,
      )
      context.arc(
        HANDLE_SIZE - HANDLE_RADIUS,
        HANDLE_RADIUS,
        HANDLE_RADIUS,
        3 * Math::PI / 2,
        0,
      )
      context.line_to(HANDLE_SIZE, HANDLE_SIZE)
      context.arc(
        HANDLE_RADIUS,
        HANDLE_SIZE - HANDLE_RADIUS,
        HANDLE_RADIUS,
        Math::PI / 2,
        Math::PI,
      )
      context.close_path
    end

    def set_color(context, color)
      color.then do |(red, green, blue, alpha)|
        context.set_source_rgba(
          red,
          green,
          blue,
          alpha || 1.0,
        )
      end
    end
end
