# frozen_string_literal: true

require 'pg'

class PG::Connection
  ESCAPER = ->(expr) {
    case expr
    when Symbol
      quote_ident(expr.to_s)
    when String
      "'#{escape(expr)}'"
    else
      nil # use default quoting
    end
  }

  def q(query = nil, **ctx, &block)
    query ||= Eno::Query.new(&block)
    exec(query_to_sql(query, **ctx))
  end

  def query_to_sql(query, **ctx)
    query.to_sql(escape_proc: ESCAPER, **ctx)
  end
end