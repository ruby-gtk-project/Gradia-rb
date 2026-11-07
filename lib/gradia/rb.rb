# frozen_string_literal: true

require_relative 'rb/version'

# Entry point for the `gradia-rb` gem's packaging/version namespace.
#
# Unlike the pilot port, Gradia's `lib/*.rb` files are not split along a
# display-free line — nearly every file (starting with `color_conversions.rb`)
# requires `adwaita`, which initialises GTK at require time. So this file only
# loads the version constant; `require 'gradia'` (not `gradia/rb`) is what
# loads the application and its widgets, and needs a display to do it.
