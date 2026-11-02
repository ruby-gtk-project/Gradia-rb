# frozen_string_literal: true

# TimestampedFilenameGenerator expands a strftime pattern against the current
# time, which is how the export and stdin paths get their default filenames.
#
# Ported from gradia/utils/timestamp_filename.py.
class TimestampedFilenameGenerator
  def generate(pattern) = Time.now.strftime(pattern)
end
