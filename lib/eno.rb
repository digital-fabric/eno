# frozen_string_literal: true

require 'modulation/gem'

export :Query, :Expression, :Identifier, :Alias

module ::Kernel
  def Q(&block)
    Query.new(&block)
  end

  def _quote(expr)
    case expr
    when Query
      "(#{expr.to_sql.strip})"
    when Expression
      expr.to_sql
    when Symbol
      expr.to_s
    when String
      "'#{expr}'"
    else
      expr.inspect
    end
  end
end

class Expression
  attr_reader :expr

  def initialize(expr)
    @expr = expr
  end

  def as(sym = nil, &block)
    if sym
      Alias.new(self, sym)
    else
      Alias.new(self, Query.new(&block))
    end
  end

  def desc
    Desc.new(self)
  end

  def over(sym = nil, &block)
    Over.new(self, sym || WindowExpression.new(&block))
  end

  def ==(expr2)
    BinaryOperator.new(self, '=', expr2)
  end

  def !=(expr2)
    BinaryOperator.new(self, '<>', expr2)
  end

  def <(expr2)
    BinaryOperator.new(self, '<', expr2)
  end

  def >(expr2)
    BinaryOperator.new(self, '>', expr2)
  end

  def <=(expr2)
    BinaryOperator.new(self, '<=', expr2)
  end

  def >=(expr2)
    BinaryOperator.new(self, '>=', expr2)
  end

  def &(expr2)
    BinaryOperator.new(self, 'and', expr2)
  end

  def |(expr2)
    BinaryOperator.new(self, 'or', expr2)
  end

  def +(expr2)
    BinaryOperator.new(self, '+', expr2)
  end

  def -(expr2)
    BinaryOperator.new(self, '-', expr2)
  end

  def *(expr2)
    BinaryOperator.new(self, '*', expr2)
  end

  def /(expr2)
    BinaryOperator.new(self, '/', expr2)
  end

  def %(expr2)
    BinaryOperator.new(self, '%', expr2)
  end

  def null?
    IsNull.new(self)
  end

  def not_null?
    IsNotNull.new(self)
  end
end

class BinaryOperator < Expression
  def initialize(expr1, op, expr2)
    @expr1 = expr1
    @op = op
    @expr2 = expr2
  end

  def to_sql
    "(#{_quote(@expr1)} #{@op} #{_quote(@expr2)})"
  end
end

class Desc < Expression
  def to_sql
    "#{_quote(@expr)} desc"
  end
end

class Over < Expression
  def initialize(expr, window)
    @expr = expr
    @window = window
  end

  def to_sql
    "#{_quote(@expr)} over #{_quote(@window)}"
  end
end

class Not < Expression
  def to_sql
    "(not #{_quote(@expr)})"
  end
end

class IsNull < Expression
  def to_sql
    "(#{_quote(@expr)} is null)"
  end
end

class IsNotNull < Expression
  def to_sql
    "(#{_quote(@expr)} is not null)"
  end
end

class WindowExpression < Expression
  def initialize(&block)
    instance_eval(&block)
  end

  def partition_by(*args)
    @partition_by = args
  end

  def order_by(*args)
    @order_by = args
  end

  def range_unbounded
    @range = 'between unbounded preceding and unbounded following'
  end

  def to_sql
    "(%s)" % [
      _partition_by_clause,
      _order_by_clause,
      _range_clause
    ].join.strip
  end

  def _partition_by_clause
    return nil unless @partition_by
    "partition by %s " % @partition_by.map { |e| _quote(e) }.join(', ')
  end

  def _order_by_clause
    return nil unless @order_by
    "order by %s " % @order_by.map { |e| _quote(e) }.join(', ')
  end

  def _range_clause
    return nil unless @range
    "range #{@range} "
  end

  def method_missing(sym)
    Identifier.new(sym)
  end
end

class QuotedExpression < Expression
  def to_sql
    _quote(@expr)
  end
end

class Identifier < Expression
  def to_sql
    @expr.to_s
  end

  def method_missing(sym)
    Identifier.new("#{@expr}.#{sym}")
  end
end

class Alias < Expression
  attr_reader :expr, :id

  def initialize(expr, id)
    @expr = expr
    @id = id
  end

  def to_sql
    "#{_quote(@expr)} as #{_quote(@id)}"
  end
end

class FunctionCall < Expression
  attr_reader :fun, :args

  def initialize(fun, *args)
    @fun = fun
    @args = args
  end

  def to_sql
    "#{@fun}(#{@args.map { |a| _quote(a) }.join(', ')})"
  end
end

class Query
  def initialize(&block)
    @clauses = {}
    @aliases = {}
    instance_eval(&block)
  end

  def _q(expr)
    QuotedExpression.new(expr)
  end

  def as(sym)
    Alias.new(self, sym)
  end

  def to_sql
    [
      _with_clause, _select_clause, _from_clause, _join_clause,
      _where_clause, _window_clause, _order_by_clause, _limit_clause
    ].join.strip
  end

  def _with_clause
    return unless @clauses[:with]

    "with %s " % @clauses[:with].map { |e| _quote(e) }.join(', ')
  end

  def _select_clause
    select = @clauses[:select] || [:*]
    "select %s%s " % [_distinct_clause, select.map { |e| _quote(e) }.join(', ')]
  end

  def _distinct_clause
    if @clauses[:distinct]
      "distinct "
    elsif on = @clauses[:distinct_on]
      if Array === on
        "distinct on (%s)"  % on.map { |e| _quote(e) }.join(', ')
      else
        "distinct on (%s)"  % _quote(on)
      end
    else
      nil
    end
  end

  def _from_clause
    from = @clauses[:from]
    if from.nil?
      return nil
    elsif Query === from
      "from %s t1 " % _quote(from)
    elsif Alias === from && Query === from.expr
      "from %s %s " % [_quote(from.expr), _quote(from.id)]
    else
      "from %s " % _quote(from)
    end
  end

  def _join_clause
  end

  def _where_clause
    return nil unless @clauses[:where]

    "where %s " % _quote(@clauses[:where])
  end

  def _window_clause
    return nil unless @clauses[:window]

    "window %s as %s " % [
      _quote(@clauses[:window].first),
      WindowExpression.new(&@clauses[:window].last).to_sql
    ]
  end

  def _order_by_clause
    return unless @clauses[:order_by]

    "order by %s " % @clauses[:order_by].map { |e| _quote(e) }.join(', ')
  end

  def _limit_clause
    return unless @clauses[:limit]

    "limit %d" % @clauses[:limit]
  end

  def method_missing(sym, *args)
    if args.empty?
      Identifier.new(sym)
    else
      FunctionCall.new(sym, *args)
    end
  end

  def with(*args)
    @clauses[:with] = args
  end

  H_EMPTY = {}.freeze

  def select(*args)
    raise "Cannot select twice" if @clauses[:select]

    props = args.size > 0 && Hash === args.last ? args.pop : H_EMPTY
       
    @clauses[:distinct] = props.delete(:distinct) if props[:distinct]
    @clauses[:distinct_on] = props.delete(:distinct_on) if props[:distinct_on]

    if args.empty? && !props.empty?
      @clauses[:select] = props.map { |k, v| Alias.new(v, k) }
    else
      @clauses[:select] = args
    end
  end

  def select_distinct(*args)
    props = args.size > 0 && Hash === args.last ? args.pop : H_EMPTY

    if props[:on]
      select(*args, props.merge(distinct_on: props[:on]))
    else
      select(*args, props.merge(distinct: true))
    end
  end

  def from(source)
    @clauses[:from] = source
  end

  def where(expr)
    @clauses[:where] = expr
  end

  def window(sym, &block)
    @clauses[:window] = [w, block]
  end

  def order_by(*args)
    @clauses[:order_by] = args
  end

  def limit(value)
    @clauses[:limit] = value
  end

  def all(sym = nil)
    if sym
      Identifier.new("#{sym}.*")
    else
      Identifier.new('*')
    end
  end

  def _not(expr)
    IsNull === expr ? IsNotNull.new(expr.expr) : Not.new(expr)
  end
end
