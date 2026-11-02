# frozen_string_literal: true

require 'adwaita'
require 'json'
require 'fileutils'
require_relative 'logger'

# Settings holds the same keys, types and defaults as upstream's
# be.alexandervanhee.gradia GSettings schema, and the same named accessors the
# rest of the app reads them through.
#
# Ported from gradia/backend/settings.py and
# data/be.alexandervanhee.gradia.gschema.xml. Upstream uses Gio::Settings, which
# needs a schema compiled into the system's glib-2.0/schemas directory before
# the app will even start; requiring an install step to run the port from a
# checkout is worse than the alternative, so the same keys are backed by a JSON
# file under XDG_CONFIG_HOME. The `bind_*` helpers keep upstream's signature
# and do by hand what Gio::Settings#bind would do.
class Settings
  SOLID_STATE_DEFAULT = '{"color": "#4A90E2", "alpha": 1.0}'
  GRADIENT_STATE_DEFAULT = '{"mode": "linear", "steps": [[0.0, "rgb(87,227,137)"], [1.0, "rgb(53,132,228)"]], "angle": 135}'

  SOURCE_SNIPPET_DEFAULT = <<~CODE.chomp
    // Gradia
    #include <pthread.h>
    #include <stdio.h>

    void* say_hello(void* arg) {
        puts("Hello from thread!");
        return NULL;
    }

    int main() {
        pthread_t t;
        pthread_create(&t, NULL, say_hello, NULL);
        pthread_join(t, NULL);
    }
  CODE

  # The seven tool presets the schema ships, verbatim: the drawing tools read
  # them back through ToolOption.deserialize.
  TOOL_CONFIG_DEFAULT = {
    'tool_highlighter' => '{"mode": "HIGHLIGHTER", "size": 14, "primary_color": [0.96, 0.83, 0.18, 0.4], "fill_color": [1.0, 1.0, 1.0, 1.0], "border_color": [0.0, 0.0, 0.0, 1.0]}',
    'tool_number'      => '{"mode": "NUMBER", "size": 14, "primary_color": [0.0, 0.0, 0.0, 1.0], "fill_color": [1.0, 1.0, 1.0, 1.0], "border_color": [0.0, 0.0, 0.0, 0.0]}',
    'tool_circle'      => '{"mode": "CIRCLE", "size": 14, "primary_color": [1.0, 1.0, 1.0, 1.0], "fill_color": [1.0, 1.0, 1.0, 1.0], "border_color": [0.0, 0.0, 0.0, 1.0]}',
    'tool_square'      => '{"mode": "SQUARE", "size": 14, "primary_color": [1.0, 1.0, 1.0, 1.0], "fill_color": [1.0, 1.0, 1.0, 1.0], "border_color": [0.0, 0.0, 0.0, 1.0]}',
    'tool_arrow'       => '{"mode": "ARROW", "size": 14, "primary_color": [0.0, 0.0, 0.0, 1.0], "fill_color": [1.0, 1.0, 1.0, 1.0], "border_color": [0.0, 0.0, 0.0, 1.0]}',
    'tool_line'        => '{"mode": "LINE", "size": 14, "primary_color": [0.0, 0.0, 0.0, 1.0], "fill_color": [1.0, 1.0, 1.0, 1.0], "border_color": [0.0, 0.0, 0.0, 1.0]}',
    'tool_pen'         => '{"mode": "PEN", "size": 14, "primary_color": [0.0, 0.0, 0.0, 1.0], "fill_color": [1.0, 1.0, 1.0, 1.0], "border_color": [0.0, 0.0, 0.0, 1.0]}',
  }.freeze

  DEFAULTS = {
    'draw-mode'                        => 'SELECT',
    'tool-config'                      => TOOL_CONFIG_DEFAULT,
    'image-padding'                    => 5,
    'image-corner-radius'              => 2,
    'image-aspect-ratio'               => '',
    'image-shadow-strength'            => 5,
    'image-auto-balance'               => false,
    'background-mode'                  => 'none',
    'solid-state'                      => SOLID_STATE_DEFAULT,
    'gradient-state'                   => GRADIENT_STATE_DEFAULT,
    'image-state'                      => '',
    'screenshot-folder'                => '',
    'export-format'                    => 'png',
    'export-compress'                  => true,
    'trash-screenshots-on-close'       => false,
    'image-options-lock'               => false,
    'exit-method'                      => 'confirm',
    'overwrite-screenshot'             => false,
    'custom-export-command'            => '',
    'provider-name'                    => '',
    'show-export-confirm-dialog'       => true,
    'source-snippet-show-frame'        => true,
    'source-snippet-show-line-numbers' => true,
    'source-snippet-language'          => 'c',
    'source-snippet-code-text'         => SOURCE_SNIPPET_DEFAULT,
    'source-snippet-title'             => 'My Code',
    'source-snippet-style-scheme'      => 'Adwaita',
    'trained-data'                     => 'eng',
  }.freeze

  EXIT_METHODS = %w[confirm copy none].freeze

  # Keys whose named accessor is a plain pass-through, and the suffix the
  # boolean ones also answer to.
  PLAIN_KEYS = {
    draw_mode:                        'draw-mode',
    export_format:                    'export-format',
    custom_export_command:            'custom-export-command',
    provider_name:                    'provider-name',
    image_padding:                    'image-padding',
    image_corner_radius:              'image-corner-radius',
    image_aspect_ratio:               'image-aspect-ratio',
    image_shadow_strength:            'image-shadow-strength',
    image_auto_balance:               'image-auto-balance',
    image_options_lock:               'image-options-lock',
    background_mode:                  'background-mode',
    solid_state:                      'solid-state',
    gradient_state:                   'gradient-state',
    image_state:                      'image-state',
    source_snippet_language:          'source-snippet-language',
    source_snippet_code_text:         'source-snippet-code-text',
    source_snippet_title:             'source-snippet-title',
    source_snippet_style_scheme:      'source-snippet-style-scheme',
    source_snippet_show_frame:        'source-snippet-show-frame',
    source_snippet_show_line_numbers: 'source-snippet-show-line-numbers',
    trained_data:                     'trained-data',
    export_compress:                  'export-compress',
    overwrite_screenshot:             'overwrite-screenshot',
    show_export_confirm_dialog:       'show-export-confirm-dialog',
  }.freeze

  def initialize(path: nil, logger: GradiaLogger.new)
    @path = path || default_path
    @logger = logger
    @values = DEFAULTS.merge(read)
  end

  def location = @path

  def keys = DEFAULTS.keys

  def [](key) = @values.fetch(key.to_s, DEFAULTS[key.to_s])

  def []=(key, value)
    @values[key.to_s] = value
    write
    value
  end

  PLAIN_KEYS.each do |name, key|
    define_method(name) { self[key] }
    define_method(:"#{name}=") { |value| self[key] = value }
    if DEFAULTS[key] == true || DEFAULTS[key] == false
      define_method(:"#{name}?") { self[key] == true }
    end
  end

  # Upstream exposes this one under a name that does not match its key.
  def delete_screenshots_on_close = self['trash-screenshots-on-close'] == true

  def delete_screenshots_on_close=(value)
    self['trash-screenshots-on-close'] = value
  end

  # Upstream turns the empty default into nil so callers can treat "unset" and
  # "set to nothing" alike.
  def screenshot_folder
    self['screenshot-folder'].then do |value|
      if value.to_s.empty?
        nil
      else
        value
      end
    end
  end

  def screenshot_folder=(value)
    self['screenshot-folder'] = value.to_s
  end

  # Anything unrecognised falls back to "confirm", on the way in and out.
  def exit_method
    self['exit-method'].then do |value|
      if EXIT_METHODS.include?(value)
        value
      else
        'confirm'
      end
    end
  end

  def exit_method=(value)
    if EXIT_METHODS.include?(value)
      self['exit-method'] = value
    else
      self['exit-method'] = 'confirm'
    end
  end

  def tool_config = self['tool-config'].dup

  def tool_config_item(key) = tool_config[key.to_s]

  def set_tool_config_item(key, value)
    self['tool-config'] = tool_config.merge(key.to_s => value)
  end

  # Two-way binding without Gio::Settings: seed the widget, then write back on
  # every change. Upstream warns and does nothing for an unknown key.
  def bind_switch(switch, key)
    with_known_key(key) do
      switch.active = self[key] == true
      switch.signal_connect('notify::active') { |widget, _param| self[key] = widget.active? }
    end
  end

  def bind_adjustment(adjustment, key)
    with_known_key(key) do
      adjustment.value = self[key].to_f
      adjustment.signal_connect('value-changed') { |widget| self[key] = widget.value.round }
    end
  end

  def bind_scale(scale, key) = bind_adjustment(scale.adjustment, key)

  def bind_spin_row(spin_row, key)
    with_known_key(key) do
      spin_row.value = self[key].to_f
      spin_row.signal_connect('notify::value') { |widget, _param| self[key] = widget.value.round }
    end
  end

  # ToggleGroup is a plain Ruby class rather than a registered Gtk type, so
  # this binds through its own `on_change` callback instead of notify::.
  def bind_toggle_group(toggle_group, key)
    with_known_key(key) do
      toggle_group.active_name = self[key]
      toggle_group.on_change { |name| self[key] = name }
    end
  end

  private

    def with_known_key(key)
      if DEFAULTS.key?(key.to_s)
        yield
      else
        @logger.warning("GSettings key '#{key}' not found in schema.")
      end
    end

    def default_path
      File.join(
        ENV.fetch('XDG_CONFIG_HOME', File.expand_path('~/.config')),
        'gradia',
        'settings.json',
      )
    end

    def read
      if File.exist?(@path)
        parse(File.read(@path))
      else
        {}
      end
    end

    def parse(contents)
      JSON.parse(contents)
    rescue JSON::ParserError => error
      @logger.warning("Ignoring unreadable settings file #{@path}", exception: error, show_exception: true)
      {}
    end

    def write
      FileUtils.mkdir_p(File.dirname(@path))
      File.write(@path, "#{JSON.pretty_generate(@values)}\n")
    end
end
