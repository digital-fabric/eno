# frozen_string_literal: true

require 'modulation/gem'

export :Query, :Expression, :Identifier, :Alias

module ::Kernel
  def Q(&block)
    Query.new(&block)
  end
end

class Expression
  def self.quote(expr)
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

  attr_reader :members, :props

  def initialize(*members, **props)
    @members = members
    @props = props
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
    Operator.new('=', self, expr2)
  end

  def !=(expr2)
    Operator.new('<>', self, expr2)
  end

  def <(expr2)
    Operator.new('<', self, expr2)
  end

  def >(expr2)
    Operator.new('>', self, expr2)
  end

  def <=(expr2)
    Operator.new('<=', self, expr2)
  end

  def >=(expr2)
    Operator.new('>=', self, expr2)
  end

  def &(expr2)
    Operator.new('and', self, expr2)
  end

  def |(expr2)
    Operator.new('or', self, expr2)
  end

  def +(expr2)
    Operator.new('+', self, expr2)
  end

  def -(expr2)
    Operator.new('-', self, expr2)
  end

  def *(expr2)
    Operator.new('*', self, expr2)
  end

  def /(expr2)
    Operator.new('/', self, expr2)
  end

  def %(expr2)
    Operator.new('%', self, expr2)
  end

  def null?
    IsNull.new(self)
  end

  def not_null?
    IsNotNull.new(self)
  end

  def join(sym, **props)
    Join.new(self, sym, **props)
  end

  def inner_join(sym, **props)
    join(sym, props.merge(type: :inner))
  end
end

class Operator < Expression
  def initialize(*members, **props)
    op = members[0]
    if Operator === members[1] && op == members[1].op
      members = [op] + members[1].members[1..-1] + members[2..-1]
    end
    if Operator === members[2] && op == members[2].op
      members = members[0..1] + members[2].members[1..-1]
    end

    super(*members, **props)
  end

  def op
    @members[0]
  end

  def to_sql
    op = " #{@members[0]} "
    "(%s)" % @members[1..-1].map { |m| Expression.quote(m) }.join(op)
  end
end

class Desc < Expression
  def to_sql
    "#{Expression.quote(@members[0])} desc"
  end
end

class Over < Expression
  def to_sql
    "#{Expression.quote(@members[0])} over #{Expression.quote(@members[1])}"
  end
end

class Not < Expression
  def to_sql
    "(not #{Expression.quote(@members[0])})"
  end
end

class IsNull < Expression
  def to_sql
    "(#{Expression.quote(@members[0])} is null)"
  end
end

class IsNotNull < Expression
  def to_sql
    "(#{Expression.quote(@members[0])} is not null)"
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
    "partition by %s " % @partition_by.map { |e| Expression.quote(e) }.join(', ')
  end

  def _order_by_clause
    return nil unless @order_by
    "order by %s " % @order_by.map { |e| Expression.quote(e) }.join(', ')
  end

  def _range_clause
    return nil unless @range
    "range #{@range} "
  end

  def method_missing(sym)
    super if sym == :to_hash
    Identifier.new(sym)
  end
end

class QuotedExpression < Expression
  def to_sql
    Expression.quote(@members[0])
  end
end

class Identifier < Expression
  def to_sql
    @members[0].to_s
  end

  def method_missing(sym)
    super if sym == :to_hash
    Identifier.new("#{@members[0]}.#{sym}")
  end

  def _empty_placeholder?
    m = @members[0]
    Symbol === m && m == :_
  end
end

class Alias < Expression
  def to_sql
    "#{Expression.quote(@members[0])} as #{Expression.quote(@members[1])}"
  end
end

class FunctionCall < Expression
  def to_sql
    fun = @members[0]
    if @members.size == 2 && Identifier === @members.last && @members.last._empty_placeholder?
      "#{fun}()"
    else
      "#{fun}(#{@members[1..-1].map { |a| Expression.quote(a) }.join(', ')})"
    end
  end
end

class Join < Expression
  H_JOIN_TYPES = {
    nil:    'join',
    inner:  'inner join',
    outer:  'outer join'
  }

  def to_sql
    ("%s %s %s %s" % [
      Expression.quote(@members[0]),
      H_JOIN_TYPES[@props[:type]],
      Expression.quote(@members[1]),
      condition_sql
    ]).strip
  end

  def condition_sql
    if @props[:on]
      'on %s' % Expression.quote(@props[:on])
    elsif using_fields = @props[:using]
      fields = using_fields.is_a?(Array) ? using_fields : [using_fields]
      'using (%s)' % fields.map { |f| Expression.quote(f) }.join(', ')
    else
      nil
    end
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
      _with_clause, _select_clause, _from_clause,
      _where_clause, _window_clause, _order_by_clause, _limit_clause
    ].join.strip
  end

  def _with_clause
    return unless @clauses[:with]

    "with %s " % @clauses[:with].map { |e| Expression.quote(e) }.join(', ')
  end

  def _select_clause
    select = @clauses[:select] || [:*]
    "select %s%s " % [_distinct_clause, select.map { |e| Expression.quote(e) }.join(', ')]
  end

  def _distinct_clause
    if @clauses[:distinct]
      "distinct "
    elsif on = @clauses[:distinct_on]
      if Array === on
        "distinct on (%s)"  % on.map { |e| Expression.quote(e) }.join(', ')
      else
        "distinct on (%s)"  % Expression.quote(on)
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
      "from %s t1 " % Expression.quote(from)
    elsif Alias === from && Query === from.members[0]
      "from %s %s " % [Expression.quote(from.members[0]), Expression.quote(from.members[1])]
    else
      "from %s " % Expression.quote(from)
    end
  end

  def _where_clause
    return nil unless @clauses[:where]

    "where %s " % Expression.quote(@clauses[:where])
  end

  def _window_clause
    return nil unless @clauses[:window]

    "window %s as %s " % [
      Expression.quote(@clauses[:window].first),
      WindowExpression.new(&@clauses[:window].last).to_sql
    ]
  end

  def _order_by_clause
    return unless @clauses[:order_by]

    "order by %s " % @clauses[:order_by].map { |e| Expression.quote(e) }.join(', ')
  end

  def _limit_clause
    return unless @clauses[:limit]

    "limit %d" % @clauses[:limit]
  end

  def method_missing(sym, *args)
    super if sym == :to_hash
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
    IsNull === expr ? IsNotNull.new(expr.members[0]) : Not.new(expr)
  end
end
