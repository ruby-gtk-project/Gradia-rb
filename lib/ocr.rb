# frozen_string_literal: true

require 'adwaita'
require 'soup3'
require 'json'
require 'pathname'
require 'tmpdir'
require 'fileutils'
require 'open3'
require_relative 'logger'
require_relative 'settings'

# OCRModel is one downloadable language pack: its tessdata code, the name the
# sidebar shows for it (translated when the UI's locale has one) and its
# download size.
#
# Ported from gradia/backend/ocr.py (the OCRModel dataclass).
OCRModel = Struct.new(:code, :name, :size)

# OCR is the Tesseract backend: it tracks which language packs are installed
# under the user's tessdata directory, downloads more from the
# tesseract_best data repository, and runs the `tesseract` binary against a
# loaded image to pull text out of it.
#
# Ported from gradia/backend/ocr.py. Upstream shells out to Tesseract through
# the `pytesseract` wrapper, which itself just spawns the `tesseract`
# executable and reads back the file it writes; this port spawns the same
# binary directly, since no Ruby binding for it exists.
class OCR
  MODELS_RESOURCE = File.join(File.expand_path('..', __dir__), 'data', 'models.json')
  TESSDATA_URL_TEMPLATE = 'https://github.com/tesseract-ocr/tessdata_best/raw/4.1.0/%<code>s.traineddata'

  @tessdata_cache = nil

  class << self
    attr_accessor :tessdata_cache
  end

  attr_reader :tesseract_cmd, :original_tessdata_dir, :user_tessdata_dir

  def initialize(window: nil, settings: nil, logger: GradiaLogger.new)
    @window = window
    @logger = logger
    @settings = settings || Settings.new
    @tesseract_cmd = ENV.fetch('GRADIA_OCR_TESSERACT_CMD', 'tesseract')
    @original_tessdata_dir = ENV.fetch('GRADIA_OCR_TESSDATA_DIR', '/usr/share/tessdata')
    @user_tessdata_dir = File.join(
      ENV.fetch('XDG_DATA_HOME', File.expand_path('~/.local/share')),
      'gradia',
      'tessdata',
    )
    @session = nil
    update_ocr_action_state
  end

  def get_downloadable_models
    load_tessdata_json.map do |code, entry|
      OCRModel.new(code, translated_name(code, entry), entry.fetch('size_bytes', 0))
    end
  end

  def get_current_model = @settings.trained_data

  def set_current_model(model_code)
    if is_model_installed(model_code)
      @settings.trained_data = model_code
      @logger.info("Setting current OCR model to: #{model_code}")
    else
      @logger.warning("Cannot set model #{model_code}: not installed")
      raise ArgumentError, "Model #{model_code} is not installed"
    end
  end

  def extract_text(image_path, primary_lang)
    if get_installed_models.empty?
      raise "No OCR language models are available"
    end

    unless is_model_installed(primary_lang)
      raise "OCR language model '#{primary_lang}' is not installed"
    end

    set_current_model(primary_lang)
    run_tesseract(image_path, primary_lang)
  end

  def get_installed_models
    [@original_tessdata_dir, @user_tessdata_dir].flat_map { |dir| traineddata_codes(dir) }.uniq.sort
  end

  def is_model_installed(model_code) = get_installed_models.include?(model_code)

  # Downloads asynchronously over Soup; `progress_callback` is invoked as
  # `(success, message)` once the transfer lands or fails.
  def download_model(model_code, progress_callback: nil)
    @session ||= Soup::Session.new
    output_path = Pathname.new(File.join(@user_tessdata_dir, "#{model_code}.traineddata"))
    output_path.dirname.mkpath

    message = Soup::Message.new('GET', format(TESSDATA_URL_TEMPLATE, code: model_code))

    @session.send_and_read_async(message, GLib::PRIORITY_DEFAULT, nil) do |session, result|
      handle_download_result(session, message, result, model_code, output_path, progress_callback)
    end
  end

  def delete_model(model_code)
    Pathname.new(File.join(@user_tessdata_dir, "#{model_code}.traineddata")).then do |path|
      if path.exist?
        path.delete
        @logger.info("Deleted OCR model: #{model_code}")
        reassign_current_model_if_needed(model_code)
        update_ocr_action_state
        true
      else
        @logger.warning("OCR model not found: #{model_code}")
        false
      end
    end
  end

  private

    def handle_download_result(session, message, result, model_code, output_path, progress_callback)
      glib_bytes = session.send_and_read_finish(result)
      unless message.status_code == 200
        raise "HTTP error #{message.status_code}"
      end

      output_path.binwrite(glib_bytes.get_data)
      @logger.info("Downloaded OCR model: #{model_code}")
      set_current_model(model_code)
      update_ocr_action_state
      progress_callback&.call(true, "Downloaded #{model_code}")
    rescue StandardError => error
      @logger.error("Failed to download OCR model #{model_code}: #{error}")
      progress_callback&.call(false, error.message)
    end

    def reassign_current_model_if_needed(model_code)
      if get_current_model == model_code
        get_installed_models.first.then { |fallback| set_current_model(fallback) if fallback }
      end
    end

    def load_tessdata_json
      OCR.tessdata_cache ||= JSON.parse(File.read(MODELS_RESOURCE))
    end

    def translated_name(code, entry)
      ui_language.then do |lang|
        if lang
          translation = entry.dig('translations', lang) || entry.dig('translations', lang.split('_').first)
          translation || entry.fetch('english_name', code)
        else
          entry.fetch('english_name', code)
        end
      end
    end

    def ui_language
      %w[LANGUAGE LC_ALL LC_MESSAGES LANG].each do |var|
        value = ENV[var]
        if value && !value.empty?
          language = value.split(':').first.split('.').first
          if language && !['C', 'POSIX'].include?(language)
            return language
          end
        end
      end
      nil
    end

    def traineddata_codes(dir)
      Dir.glob(File.join(dir, '*.traineddata')).filter_map do |path|
        code = File.basename(path, '.traineddata')
        code unless code == 'osd'
      end
    end

    def run_tesseract(image_path, primary_lang)
      tessdata_dir = tessdata_dir_for(primary_lang)
      lang = language_argument(primary_lang)
      output_base = File.join(Dir.mktmpdir('gradia-ocr'), 'out')

      run_command(
        [
          @tesseract_cmd,
          image_path,
          output_base,
          '--tessdata-dir', tessdata_dir,
          '-l', lang,
        ],
      )
      File.read("#{output_base}.txt").strip
    ensure
      FileUtils.rm_rf(File.dirname(output_base)) if output_base
    end

    def language_argument(primary_lang)
      if is_model_installed('eng') && primary_lang != 'eng'
        "#{primary_lang}+eng"
      else
        primary_lang
      end
    end

    def tessdata_dir_for(lang_code)
      if File.exist?(File.join(@user_tessdata_dir, "#{lang_code}.traineddata"))
        @user_tessdata_dir
      else
        @original_tessdata_dir
      end
    end

    def run_command(argv)
      _out, err, status = Open3.capture3(*argv)
      unless status.success?
        raise "OCR processing failed: #{err}"
      end
    end

    def update_ocr_action_state
      @window&.lookup_action('ocr').then do |action|
        if action.respond_to?(:state=)
          action.state = GLib::Variant.new(File.exist?(@tesseract_cmd) || which?(@tesseract_cmd))
        end
      end
    end

    def which?(cmd)
      ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, cmd)) }
    end
end
