# frozen_string_literal: true

module ::Kernel
  def Q(**ctx, &block)
    Eno::Query.new(**ctx, &block)
  end
end

require_relative 'eno/expression'
require_relative 'eno/sql'
require_relative 'eno/query'

module Eno
end
