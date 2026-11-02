# frozen_string_literal: true

# GradiaLogger prints log lines the way upstream does: a bracketed,
# ANSI-coloured level tag in front of the message, optional exception and
# backtrace blocks indented under it, and an issue footer after the levels
# worth reporting.
#
# Ported from gradia/backend/logger.py. Upstream subclasses Python's
# `logging.Logger`; Ruby's stdlib Logger prepends a timestamp and severity of
# its own and cannot be made to produce upstream's format without replacing the
# formatter anyway, so the levels and the colouring are implemented directly.
#
# The class is NOT called `Logger`: that constant belongs to Ruby's stdlib, and
# reopening it with a different constructor would break every gem that expects
# the stdlib one.
#
# Upstream decides whether debug messages are emitted from the build type baked
# into gradia/constants.in at compile time; a Ruby checkout has no compile step,
# so the same switch reads GRADIA_BUILD_TYPE from the environment.
class GradiaLogger
  LOG_COLORS = {
    'debug'    => 32,
    'info'     => 36,
    'warning'  => 33,
    'error'    => 31,
    'critical' => 41,
  }.freeze

  ISSUE_FOOTER = 'If you are reporting an issue, please copy the logs printed above to the issue body.'

  DEFAULT_ISSUE_FOOTER_LEVELS = %w[error traceback_error critical].freeze

  attr_reader :issue_footer_levels

  def initialize(issue_footer_levels: nil, io: $stderr)
    @issue_footer_levels = issue_footer_levels || DEFAULT_ISSUE_FOOTER_LEVELS
    @io = io
    @silent = false
  end

  def build_type = ENV.fetch('GRADIA_BUILD_TYPE', 'release')

  def debug?  = build_type == 'debug'

  def debug(message)
    if debug?
      write(level_color('debug', message.to_s))
    end
  end

  def info(message) = write(level_color('info', message.to_s))

  def warning(message, exception: nil, show_exception: false, show_traceback: false)
    emit(
      'warning',
      message,
      exception,
      show_exception,
      show_traceback,
    )
  end

  def error(message, exception: nil, show_exception: false, show_traceback: false)
    emit(
      'error',
      message,
      exception,
      show_exception,
      show_traceback,
    )
  end

  # Upstream's traceback_error always appends the backtrace and reports under
  # the `error` level, but checks the footer against its own name.
  def traceback_error(message, exception: nil, show_exception: false)
    decorate(
      message,
      exception,
      show_exception,
      true,
    ).then do |decorated|
      write(level_color('error', decorated))
      print_issue_footer_for('traceback_error')
    end
  end

  def critical(message, exception: nil, show_exception: false, show_traceback: true)
    emit(
      'critical',
      message,
      exception,
      show_exception,
      show_traceback,
    )
  end

  def set_silent = @silent = true

  def print_issue_footer = write(level_color('info', ISSUE_FOOTER))

  # Upstream returns None for a missing exception rather than an empty string.
  def get_traceback(exception)
    if exception
      ([
        "#{exception.class}: #{exception.message}",
      ] + Array(exception.backtrace).map { |line| "  from #{line}" }).join("\n")
    end
  end

  private

    def emit(level, message, exception, show_exception, show_traceback)
      decorate(
        message,
        exception,
        show_exception,
        show_traceback,
      ).then do |decorated|
        write(level_color(level, decorated))
        print_issue_footer_for(level)
      end
    end

    def decorate(message, exception, show_exception, show_traceback)
      message.to_s.dup.tap do |text|
        if show_exception
          text << exception_info(exception)
        end
        if show_traceback
          text << traceback_info(exception)
        end
      end
    end

    def print_issue_footer_for(level)
      if @issue_footer_levels.include?(level)
        print_issue_footer
      end
    end

    def exception_info(exception)
      indent("\n\t\e[1mException:\e[0m", "\n#{exception}")
    end

    def traceback_info(exception)
      indent("\n\t\e[1mTraceback:\e[0m", "\n\e[90m#{get_traceback(exception)}\e[0m")
    end

    # Upstream indents the body of both blocks by two tabs, by replacing every
    # newline inside it after the head has been split off.
    def indent(head, body) = head + body.gsub("\n", "\n\t\t")

    def level_color(level, message) = "[\e[1;#{LOG_COLORS.fetch(level)}m#{level.upcase}\e[0m] #{message}"

    def write(line)
      unless @silent
        @io.puts(line)
      end
    end
end
