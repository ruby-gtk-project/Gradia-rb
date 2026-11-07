# frozen_string_literal: true

# Plain checks on the ported models and backends: no widgets, no main loop.
# Run with: nix develop --command ruby test/check_models.rb
require 'tmpdir'
require 'stringio'
require 'fileutils'

ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir
ENV['XDG_CACHE_HOME'] = Dir.mktmpdir

require_relative '../lib/gradia'

$failures = []
$checks = 0

def check(description)
  $checks += 1
  result = yield
  unless result
    $failures << description
  end
  puts "  #{result ? 'ok  ' : 'FAIL'}  #{description}"
rescue StandardError => error
  $failures << "#{description} (#{error.class}: #{error.message})"
  puts "  ERR   #{description} — #{error.class}: #{error.message}"
  puts error.backtrace.first(3).map { |line| "          #{line}" }
end

def section(name) = puts("\n#{name}")

section 'Colors'
check('hex to rgb') { Colors.hex_to_rgb('#4A90E2') == [74, 144, 226] }
check('rgba round trip') { Colors.rgba_to_hex(Colors.hex_to_rgba('#ff8000')) == '#ff8000ff' }
check('alpha override') { Colors.hex_to_rgba('#ffffff', 0.5).alpha.round(2) == 0.5 }
check('light colour') { Colors.light_color_hex?('#ffffff') && !Colors.light_color_hex?('#000000') }
check('transparent counts as light') { Colors.light_color_hex?('#00000000') }
check('visible colour') { Colors.has_visible_color?(
  Gdk::RGBA.new(
    0,
    0,
    0,
    1,
  ),
) }
check('invisible colour') { !Colors.has_visible_color?(
  Gdk::RGBA.new(
    0,
    0,
    0,
    0,
  ),
) }
check('parse rgb string') { Colors.parse_rgb_string('rgb(87,227,137)') == [87, 227, 137] }
check('rgb string round trip') { Colors.rgb_string(
  Gdk::RGBA.new(
    1,
    0,
    0,
    1,
  ),
) == 'rgb(255,0,0)' }
check('bad rgb string raises') do
  begin
    Colors.parse_rgb_string('#fff')
    false
  rescue ArgumentError
    true
  end
end

section 'AspectRatio'
check('empty is free') { AspectRatio.parse('  ').nil? }
check('pair') { AspectRatio.parse('16:9').round(4) == (16.0 / 9).round(4) }
check('decimal') { AspectRatio.parse('1.5') == 1.5 }
check('zero denominator raises') do
  begin
    AspectRatio.parse('4:0')
    false
  rescue ArgumentError
    true
  end
end
check('bounds') { AspectRatio.within_bounds?(1.0) && !AspectRatio.within_bounds?(6.0) }

section 'TimestampedFilenameGenerator'
check('expands pattern') { TimestampedFilenameGenerator.new.generate('%Y') == Time.now.strftime('%Y') }

section 'Settings'
settings = Settings.new
check('schema defaults') { settings.draw_mode == 'SELECT' && settings.image_padding == 5 }
check('empty screenshot folder reads as nil') { settings.screenshot_folder.nil? }
check('exit method validated on write') do
  settings.exit_method = 'nonsense'
  settings.exit_method == 'confirm'
end
check('exit method accepts known value') do
  settings.exit_method = 'copy'
  settings.exit_method == 'copy'
end
check('boolean predicate') { settings.export_compress? == true }
check('tool config defaults present') { settings.tool_config.keys.length == 7 }
check('tool config item write') do
  settings.set_tool_config_item('tool_pen', '{"mode":"PEN"}')
  settings.tool_config_item('tool_pen') == '{"mode":"PEN"}'
end
check('persists across instances') do
  settings.image_padding = 11
  Settings.new.image_padding == 11
end
check('unknown key binding warns, does not raise') do
  Settings.new.bind_switch(Gtk::Switch.new, 'no-such-key')
  true
end

section 'Gradient'
gradient = Gradient.new
check('defaults') { gradient.mode == 'linear' && gradient.angle == 135.0 && gradient.steps.length == 2 }
check('json round trip') do
  Gradient.from_json(gradient.to_json).then { |other| other.to_json == gradient.to_json }
end
check('bad json falls back to default') { Gradient.from_json('not json').mode == 'linear' }
check('linear css') { gradient.to_css.start_with?('linear-gradient(135.00deg, rgb(87,227,137) 0.00%') }
check('conic css') { Gradient.new(mode: 'conic', angle: 90).to_css.start_with?('conic-gradient(from 90.00deg') }
check('radial css') { Gradient.new(mode: 'radial').to_css.start_with?('radial-gradient(circle,') }
check('unknown mode has no css') { Gradient.new(mode: 'spiral').to_css.empty? }

%w[linear radial conic].each do |mode|
  check("#{mode} renders a surface") do
    GradientBackground.new(gradient: Gradient.new(mode: mode, angle: 45)).prepare_image(40, 30).then do |surface|
      surface.width == 40 && surface.height == 30
    end
  end
end

check('gradient background json round trip') do
  GradientBackground.from_json(GradientBackground.new.to_json).gradient.mode == 'linear'
end
check('conic steps wrap back to the first colour') do
  GradientBackground.new.then do |background|
    background.gradient.mode = 'conic'
    background.conic_steps.first.last == background.conic_steps.last.last
  end
end
check('gradient name') { GradientBackground.new.name == 'Gradient' }
check('predefined gradients all render') do
  AppConstants::PREDEFINED_GRADIENTS.all? do |preset|
    GradientBackground.new(gradient: preset).prepare_image(8, 8).width == 8
  end
end

section 'SolidBackground'
solid = SolidBackground.new
check('defaults') { solid.color == '#4A90E2' && solid.alpha == 1.0 }
check('name changes with configuration') { solid.name == 'solid-#4A90E2-1.0' }
check('json round trip') { SolidBackground.from_json(solid.to_json).color == solid.color }
check('renders the colour it was given') do
  SolidBackground.new(color: '#ff0000').prepare_image(4, 4).then do |surface|
    surface.data.unpack('C4').then { |(blue, green, red, alpha)| red == 255 && green.zero? && blue.zero? && alpha == 255 }
  end
end
check('bad json falls back to the default colour') { SolidBackground.from_json('{').color == '#4A90E2' }

section 'ImageBackground'
image_background = ImageBackground.new(file_path: File.join(AppConstants::IMAGES_DIR, 'graph.png'))
check('loads a png') { !image_background.image.nil? && image_background.load_error.nil? }
check('name includes the path') { image_background.name.end_with?('graph.png') }
check('prepare_image covers the target size') do
  image_background.prepare_image(100, 50).then { |surface| surface.width == 100 && surface.height == 50 }
end
check('missing file records an error instead of raising') do
  ImageBackground.new(file_path: '/nonexistent/x.png').then do |broken|
    broken.image.nil? && !broken.load_error.nil? && broken.prepare_image(10, 10).nil?
  end
end
check('saves a copy for the next launch') do
  image_background.save_image_copy
  File.exist?(image_background.saved_image_path)
end

section 'LoadedImage'
loaded = LoadedImage.new(File.join(AppConstants::IMAGES_DIR, 'graph.png'), ImageOrigin::FILE_DIALOG)
check('loads') { loaded.loaded? }
check('preview is downscaled below the pixel budget') do
  loaded.preview_image.width * loaded.preview_image.height <= LoadedImage::MAX_PIXEL_AMOUNT
end
check('full resolution is untouched') { loaded.full_res_image.width == 2048 }
check('padding analysis ran') { !loaded.balanced_padding.nil? }
check('padding totals') do
  loaded.balanced_padding.then do |padding|
    padding.total_horizontal == padding.left + padding.right &&
      padding.max_padding == [padding.top, padding.bottom, padding.left, padding.right].max
  end
end
check('file origin keeps its filename') { loaded.proper_name == 'graph.png' }
check('name without extension') { loaded.proper_name(with_extension: false) == 'graph' }
check('file origin has a real folder') { loaded.proper_folder == 'images' && loaded.proper_folder? }
check('clipboard origin is labelled') do
  LoadedImage.new(loaded.image_path, ImageOrigin::CLIPBOARD).then do |clip|
    clip.proper_name == 'Clipboard Image' && !clip.proper_name? && clip.proper_folder == 'From clipboard'
  end
end
check('screenshot origin is recognised') do
  LoadedImage.new(loaded.image_path, ImageOrigin::SCREENSHOT).screenshot?
end
check('missing file reports instead of raising') do
  LoadedImage.new('/nonexistent/x.png', ImageOrigin::FILE_DIALOG).then do |missing|
    !missing.loaded? && missing.load_error.include?('not found')
  end
end
check('uniform image has no padding to balance') do
  Dir.mktmpdir do |dir|
    File.join(dir, 'flat.png').tap do |path|
      GdkPixbuf::Pixbuf.new(colorspace: :rgb, has_alpha: true, bits_per_sample: 8, width: 8, height: 8)
        .tap { |pixbuf| pixbuf.fill!(0x112233ff) }
        .save(path, 'png')
    end.then do |path|
      LoadedImage.new(path, ImageOrigin::FILE_DIALOG).balanced_padding.max_padding.zero?
    end
  end
end

section 'ImageProcessor'
check('composites onto a solid background with padding') do
  ImageProcessor.new(image: loaded, background: SolidBackground.new, padding: 10).then do |processor|
    pixbuf, full_width, full_height = processor.process
    pixbuf.width > loaded.preview_image.width && full_width > 0 && full_height > 0
  end
end
check('negative padding crops instead of padding') do
  ImageProcessor.new(image: loaded, padding: -10).then do |processor|
    pixbuf, = processor.process
    pixbuf.width < loaded.preview_image.width
  end
end
check('aspect ratio widens or heightens the canvas') do
  ImageProcessor.new(image: loaded, aspect_ratio: '16:9').then do |processor|
    pixbuf, = processor.process
    (pixbuf.width.to_f / pixbuf.height).round(2) == (16.0 / 9).round(2)
  end
end
check('rounded corners and a shadow do not raise') do
  ImageProcessor.new(
    image:           loaded,
    background:      SolidBackground.new,
    padding:         5,
    corner_radius:   15,
    shadow_strength: 4,
  ).process[0].is_a?(GdkPixbuf::Pixbuf)
end
check('rotation turns a wider image taller') do
  ImageProcessor.new(image: loaded, rotation: 90).then do |processor|
    pixbuf, = processor.process
    pixbuf.height == loaded.preview_image.width && pixbuf.width == loaded.preview_image.height
  end
end
check('full resolution render scales up from the preview') do
  ImageProcessor.new(image: loaded, background: SolidBackground.new, padding: 10).then do |processor|
    processor.process
    full = processor.process_full_resolution
    full.width > loaded.preview_image.width
  end
end
check('a missing image refuses instead of silently rendering blank') do
  LoadedImage.new('/nonexistent/x.png', ImageOrigin::FILE_DIALOG).then do |missing|
    begin
      ImageProcessor.new(image: missing)
      false
    rescue ArgumentError
      true
    end
  end
end

section 'DrawingMode'
check('ten tools') { DrawingMode::ALL.length == 10 }
check('lookup by name') { DrawingMode['PEN'] == DrawingMode::PEN }
check('labels') { DrawingMode::SQUARE.label == 'Rectangle' && DrawingMode::CIRCLE.label == 'Oval' }
check('shortcuts') { DrawingMode::NUMBER.shortcuts.include?('9') && DrawingMode::SELECT.shortcuts.include?('s') }
check('unknown name raises') do
  begin
    DrawingMode['NOPE']
    false
  rescue KeyError
    true
  end
end

section 'ToolOption'
written = []
option = ToolOption.new(DrawingMode::PEN) { |changed| written << changed.mode.name }
check('defaults') { option.size == 14 && option.font == 'Adwaita Sans' }
check('default colours') do
  Colors.components(option.primary_color) == [0.0, 0.0, 0.0, 1.0] &&
    Colors.components(option.border_color) == [0.0, 0.0, 0.0, 0.0]
end
check('size change notifies once') do
  option.size = 20
  option.size = 20
  option.size == 20 && written.length == 1
end
check('colour change notifies') do
  option.primary_color = Gdk::RGBA.new(
    1,
    0,
    0,
    1,
  )
  Colors.components(option.primary_color).first == 1.0 && written.length == 2
end
check('silent update does not notify') do
  option.update_without_notify(size: 33)
  option.size == 33 && written.length == 2
end
check('serialise round trip') do
  ToolOption.deserialize(option.serialize).then do |other|
    other.size == option.size && other.mode == option.mode && other.font == option.font
  end
end
check('temporary copy does not notify') do
  option.copy(is_temporary: true).then do |copy|
    copy.size = 44
    copy.size == 44 && written.length == 2
  end
end
check('plain copy keeps the callback') do
  option.copy.then do |copy|
    copy.size = 55
    written.length == 3
  end
end

section 'ToolOptionsManager'
manager = ToolOptionsManager.new(settings: Settings.new)
check('one option per tool') { DrawingMode::ALL.all? { |mode| manager.tool(mode).mode == mode } }
check('highlighter default comes from the stored schema values') do
  Colors.components(manager.tool(DrawingMode::HIGHLIGHTER).primary_color).last.round(2) == 0.4
end
check('a change is written back to the settings') do
  manager.tool(DrawingMode::ARROW).size = 7
  Settings.new.tool_config_item('tool_arrow').include?('"size":7')
end
check('export config covers every tool') { manager.export_config.keys.length == 10 }

section 'ToolConfig'
positions = ToolConfig.all_tools_positions
check('ten entries') { positions.length == 10 }
check('grid is two rows of five') do
  positions.map { |config| [config.column, config.row] }.uniq.length == 10 &&
    positions.map(&:row).uniq.sort == [0, 1]
end
check('select tool has no options') do
  positions.first.then { |config| config.mode == DrawingMode::SELECT && !config.scale? && !config.primary_color? }
end
check('number tool matches primary to secondary') do
  positions.last.then { |config| config.match_primary_to_secondary? && config.shown_stack == 'fill-border' }
end

section 'Drawing actions'
identity = ->(x, y) { [x, y] }
surface = Cairo::ImageSurface.new(Cairo::FORMAT_ARGB32, 200, 200)
context = Cairo::Context.new(surface)
pen = ToolOption.new(
  DrawingMode::PEN,
  size:          4,
  primary_color: Gdk::RGBA.new(
    1,
    0,
    0,
    1,
  ),
)

actions = {
  'stroke'      => StrokeAction.new([[0, 0], [10, 10], [20, 0], [30, 10]], pen),
  'single line' => StrokeAction.new([[0, 0], [5, 5]], pen),
  'arrow'       => ArrowAction.new(
    [0, 0],
    [50, 50],
    false,
    pen,
  ),
  'line'        => LineAction.new(
    [0, 0],
    [50, 0],
    false,
    pen,
  ),
  'rect'        => RectAction.new(
    [0, 0],
    [60, 40],
    false,
    pen,
  ),
  'circle'      => CircleAction.new(
    [0, 0],
    [60, 40],
    false,
    pen,
  ),
  'highlighter' => HighlighterAction.new([[0, 0], [40, 10]], pen, false),
  'number'      => NumberStampAction.new([20, 20], 3, pen),
  'text'        => TextAction.new(
    [20, 20],
    "hello\nthere",
    [200, 200],
    pen,
    14,
  ),
}

actions.each do |name, action|
  check("#{name} draws without raising") do
    action.draw(context, identity, 1.0)
    true
  end
  check("#{name} reports bounds") { action.bounds.bounding_rect.length == 4 }
  check("#{name} translates") do
    action.bounds.bounding_rect.then do |before|
      action.translate(5, 5)
      action.bounds.bounding_rect.then { |after| after[0] == before[0] + 5 }
    end
  end
end

check('stroke bounds include the stroke padding') do
  StrokeAction.new([[0, 0], [10, 0]], pen).bounds.bounding_rect == [-2, -2, 12, 2]
end
check('shift snaps an arrow to an axis') do
  ArrowAction.new(
    [0, 0],
    [50, 10],
    true,
    pen,
  ).end_point == [50, 0]
end
check('shift squares a rectangle') do
  RectAction.new(
    [0, 0],
    [60, 20],
    true,
    pen,
  ).bounds.bounding_rect == [0, 0, 60, 60]
end
check('shift flattens a highlighter stroke') do
  HighlighterAction.new([[0, 0], [40, 30]], pen, true).stroke == [[0, 0], [40, 0]]
end
check('a click on a line counts as a hit') do
  LineAction.new(
    [0, 0],
    [100, 0],
    false,
    pen,
  ).contains_point?(50, 2)
end
check('a click away from a line misses') do
  LineAction.new(
    [0, 0],
    [100, 0],
    false,
    pen,
  ).contains_point?(50, 400) == false
end
check('a click inside a rectangle counts as a hit') do
  RectAction.new(
    [0, 0],
    [60, 40],
    false,
    pen,
  ).contains_point?(30, 20)
end
check('a click outside a number stamp misses') do
  NumberStampAction.new([0, 0], 1, pen).contains_point?(100, 100) == false
end
check('text with only whitespace collapses to a point') do
  TextAction.new(
    [7, 9],
    '   ',
    [100, 100],
    pen,
    14,
  ).bounds.bounding_rect == [7, 9, 7, 9]
end
check('emoji text is detected') { TextAction.new(
  [0, 0],
  '★',
  [10, 10],
  pen,
  14,
).emoji? }
check('plain text is not') { !TextAction.new(
  [0, 0],
  'abc',
  [10, 10],
  pen,
  14,
).emoji? }
check('shadow colour flips with luminance') do
  StrokeAction.new([], pen).then do |action|
    action.shadow_color(
      Gdk::RGBA.new(
        0,
        0,
        0,
        1,
      ),
    ).first == 1.0 &&
      action.shadow_color(
        Gdk::RGBA.new(
          1,
          1,
          1,
          1,
        ),
      ).first.zero?
  end
end
check('censor pixelates from its backing pixbuf') do
  GdkPixbuf::Pixbuf.new(file: File.join(AppConstants::IMAGES_DIR, 'graph.png')).then do |pixbuf|
    CensorAction.new(
      [-20, -20],
      [20, 20],
      pixbuf,
      pen,
    ).then do |censor|
      censor.original_scale = 1.0
      censor.draw(context, identity, 1.0)
      censor.bounds.bounding_rect == [-20, -20, 20, 20]
    end
  end
end
check('a censor outside the image draws nothing') do
  GdkPixbuf::Pixbuf.new(file: File.join(AppConstants::IMAGES_DIR, 'graph.png')).then do |pixbuf|
    CensorAction.new(
      [9000, 9000],
      [9100, 9100],
      pixbuf,
      pen,
    ).draw(context, identity, 1.0)
    true
  end
end
check('quad bounds from a rect') { QuadBounds.from_rect(
  0,
  1,
  2,
  3,
).points.length == 4 }
check('quad bounds normalise a backwards drag') do
  QuadBounds.from_start_end([10, 10], [0, 0]).bounding_rect == [0, 0, 10, 10]
end

section 'AppConstants'
check('six predefined gradients') { AppConstants::PREDEFINED_GRADIENTS.length == 6 }
check('nine preset images, all present') do
  AppConstants::PRESET_IMAGES.length == 9 && AppConstants::PRESET_IMAGES.all? { |path| File.exist?(path) }
end
check('three export formats') { AppConstants::SUPPORTED_EXPORT_FORMATS.keys.sort == %w[jpeg png webp] }
check('extension lookup') { AppConstants.export_format_for('.JPG').first == 'jpeg' }
check('unknown extension') { AppConstants.export_format_for('.bmp').nil? }
check('help text ships') { AppConstants.help_text.length.positive? }

section 'Style'
check('stylesheet is readable') { Style.new.css.include?('.recent-button') }

section 'Clipboard'
check('saves a pixbuf to a path') do
  Dir.mktmpdir do |dir|
    GdkPixbuf::Pixbuf.new(file: File.join(AppConstants::IMAGES_DIR, 'graph.png')).then do |pixbuf|
      File.exist?(Clipboard.save_pixbuf_to_path(dir, pixbuf))
    end
  end
end

section 'StdinImageLoader'
check('a tty means nothing was piped in') do
  StdinImageLoader.new(input: Class.new { def tty? = true }.new).read_from_stdin.nil?
end
check('decodes a piped png') do
  File.join(AppConstants::IMAGES_DIR, 'graph.png').then do |path|
    StringIO.new(File.binread(path)).then do |input|
      input.define_singleton_method(:tty?) { false }
      input.define_singleton_method(:binmode) { self }
      StdinImageLoader.new(input: input).read_from_stdin.then { |result| File.exist?(result.to_s) }
    end
  end
end
check('rubbish on stdin is refused') do
  StringIO.new('not an image').then do |input|
    input.define_singleton_method(:tty?) { false }
    input.define_singleton_method(:binmode) { self }
    StdinImageLoader.new(input: input).read_from_stdin.nil?
  end
end

section 'GradiaLogger'
check('levels are tagged and coloured') do
  StringIO.new.then do |io|
    GradiaLogger.new(io: io).info('hello')
    io.string.include?('[') && io.string.include?('INFO') && io.string.include?('hello')
  end
end
check('an error prints the issue footer') do
  StringIO.new.then do |io|
    GradiaLogger.new(io: io).error('boom')
    io.string.include?(GradiaLogger::ISSUE_FOOTER)
  end
end
check('a warning does not') do
  StringIO.new.then do |io|
    GradiaLogger.new(io: io).warning('careful')
    !io.string.include?(GradiaLogger::ISSUE_FOOTER)
  end
end
check('traceback is indented under the message') do
  StringIO.new.then do |io|
    begin
      raise ArgumentError, 'nope'
    rescue ArgumentError => error
      GradiaLogger.new(io: io).traceback_error('failed', exception: error, show_exception: true)
    end
    io.string.include?('Traceback') && io.string.include?('nope')
  end
end
check('silent logger writes nothing') do
  StringIO.new.then do |io|
    GradiaLogger.new(io: io).tap(&:set_silent).info('quiet')
    io.string.empty?
  end
end
check('debug is suppressed outside a debug build') do
  StringIO.new.then do |io|
    GradiaLogger.new(io: io).debug('noisy')
    io.string.empty?
  end
end

section 'RecentImageGetter'
check('a missing folder reports nil') do
  Settings.new.tap { |s| s.screenshot_folder = '/nonexistent/folder' }.then do |s|
    RecentImageGetter.new(settings: s).recent_screenshot_files.nil?
  end
end
check('newest images first, capped at six') do
  Dir.mktmpdir do |dir|
    9.times do |index|
      File.join(dir, "shot#{index}.png").tap do |path|
        FileUtils.cp(File.join(AppConstants::IMAGES_DIR, 'graph.png'), path)
        File.utime(Time.now - (index * 60), Time.now - (index * 60), path)
      end
    end
    FileUtils.touch(File.join(dir, 'notes.txt'))

    Settings.new.tap { |s| s.screenshot_folder = dir }.then do |s|
      RecentImageGetter.new(settings: s).recent_screenshot_files.then do |files|
        files.length == 6 && files.first.name == 'shot0.png' && files.none? { |f| f.name.end_with?('.txt') }
      end
    end
  end
end

section 'OCR'
Dir.mktmpdir do |tessdata_dir|
  Dir.mktmpdir do |data_home|
    ENV['GRADIA_OCR_TESSDATA_DIR'] = tessdata_dir
    ENV['GRADIA_OCR_TESSERACT_CMD'] = '/nonexistent/tesseract'
    ENV['XDG_DATA_HOME'] = data_home
    OCR.tessdata_cache = nil

    ocr = OCR.new(settings: Settings.new)
    check('downloadable models come from the bundled resource') { !ocr.get_downloadable_models.empty? }
    check('each downloadable model carries a name and a size') do
      ocr.get_downloadable_models.all? { |model| !model.name.to_s.empty? && model.size.is_a?(Integer) }
    end
    check('nothing installed on a fresh tessdata directory') { ocr.get_installed_models.empty? }
    check('an uninstalled model is reported as such') { !ocr.is_model_installed('eng') }
    check('setting an uninstalled model raises') do
      begin
        ocr.set_current_model('eng')
        false
      rescue ArgumentError
        true
      end
    end
    check('extracting with nothing installed refuses instead of shelling out') do
      begin
        ocr.extract_text(File.join(AppConstants::IMAGES_DIR, 'graph.png'), 'eng')
        false
      rescue RuntimeError => error
        error.message.include?('No OCR language models')
      end
    end
    check('deleting a model that is not there reports failure, not an exception') do
      !ocr.delete_model('eng')
    end

    # delete_model only ever touches the user's own tessdata directory, never
    # the system one (deleting a system-owned file is not the app's call), so
    # the install used to exercise it lands in user_tessdata_dir.
    File.join(ocr.user_tessdata_dir, 'eng.traineddata').tap do |path|
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, 'stub')
    end
    check('a traineddata file on disk is picked up as installed') { ocr.get_installed_models.include?('eng') }
    check('installed models exclude the osd data') do
      File.join(ocr.user_tessdata_dir, 'osd.traineddata').tap { |path| File.write(path, 'stub') }
      !OCR.new(settings: Settings.new).get_installed_models.include?('osd')
    end
    check('extracting with an uninstalled language still refuses') do
      begin
        ocr.extract_text(File.join(AppConstants::IMAGES_DIR, 'graph.png'), 'fra')
        false
      rescue RuntimeError => error
        error.message.include?("'fra' is not installed")
      end
    end
    check('setting an installed model takes') do
      ocr.set_current_model('eng')
      ocr.get_current_model == 'eng'
    end
    check('deleting the installed model removes its file') do
      ocr.delete_model('eng')
      !File.exist?(File.join(ocr.user_tessdata_dir, 'eng.traineddata'))
    end
    check('a window with no ocr action does not raise while syncing state') do
      OCR.new(window: Gtk::ApplicationWindow.new(Gtk::Application.new), settings: Settings.new)
      true
    end
  end
end

puts "\n#{$checks} checks, #{$failures.length} failed"
$failures.each { |failure| puts "  FAILED: #{failure}" }
exit($failures.empty? ? 0 : 1)
