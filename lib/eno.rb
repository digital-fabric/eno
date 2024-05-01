# frozen_string_literal: true

# Kernel extensions
module ::Kernel
  # Builds a new query with the given block.
  #
  # @param **ctx [Hash] query context values
  # @param &block [Proc] query DSL code
  # @return [Eno::Query] query object
  def Q(**ctx, &block)
    Eno::Query.new(**ctx, &block)
  end
end

require_relative 'eno/connection'
require_relative 'eno/expression'
require_relative 'eno/sql'
require_relative 'eno/query'

# Eno is not an ORM
module Eno
  # Loads an Eno extension to provide additional methods in the query context
  #
  # @param mod [Module] extension module
  # @return [void]
  def self.extension(mod)
    SQL.include(mod)
  end
end
