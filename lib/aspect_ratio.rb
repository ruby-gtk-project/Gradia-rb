# frozen_string_literal: true

# AspectRatio parses the aspect-ratio strings the sidebar entry accepts —
# "16:9", "1.78" or empty for free — and says whether a ratio is one the
# exporter will accept.
#
# Ported from gradia/utils/aspect_ratio.py.
module AspectRatio
  MIN_RATIO = 0.2
  MAX_RATIO = 5

  module_function

  # nil for empty input (free aspect), the ratio otherwise. Raises for a
  # zero denominator or unparsable text, exactly as upstream does.
  def parse(text)
    text.to_s.strip.then do |trimmed|
      if trimmed.empty?
        nil
      elsif trimmed.include?(':')
        ratio_from_pair(trimmed)
      else
        Float(trimmed)
      end
    end
  end

  def within_bounds?(ratio, min_ratio: MIN_RATIO, max_ratio: MAX_RATIO)
    ratio >= min_ratio && ratio <= max_ratio
  end

  def ratio_from_pair(text)
    text.split(':', 2).map { |part| Float(part) }.then do |(numerator, denominator)|
      if denominator.zero?
        raise ArgumentError, 'Denominator cannot be zero'
      end

      numerator / denominator
    end
  end
end
