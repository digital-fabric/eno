# frozen_string_literal: true

require 'modulation/gem'

export_default :Eno

module ::Kernel
  def Q(**ctx, &block)
    Eno::Query.new(**ctx, &block)
  end
end

module Eno
  include_from('./eno/expressions')
  SQL = import('./eno/sql')
  Query = import('./eno/query')
end