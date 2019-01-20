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

  # not
  def !@
    Not.new(self)
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

  def !@
    IsNotNull.new(members[0])
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

class From < Expression
  def to_sql
    "from %s" % @members.map { |m| member_sql(m) }.join(', ')
  end

  def member_sql(member)
    if Query === member
      "%s t1" % Expression.quote(member)
    elsif Alias === member && Query === member.members[0]
      "%s %s" % [Expression.quote(member.members[0]), Expression.quote(member.members[1])]
    else
      Expression.quote(member)
    end
  end
end

class With < Expression
  def to_sql
    "with %s" % @members.map { |e| Expression.quote(e) }.join(', ')
  end
end

class Select < Expression
  def to_sql
    "select %s%s" % [distinct_clause, @members.map { |e| Expression.quote(e) }.join(', ')]
  end

  def distinct_clause
    case (on = @props[:distinct])
    when nil
      nil
    when true
      "distinct "
    when Array
      "distinct on (%s) "  % on.map { |e| Expression.quote(e) }.join(', ')
    else
      "distinct on %s "  % Expression.quote(on)
    end
  end
end

class Where < Expression
  def to_sql
    "where %s" % @members.map { |e| Expression.quote(e) }.join(' and ')
  end
end

class Window < Expression
  def initialize(sym, &block)
    super(sym)
    @block = block
  end

  def to_sql
    "window %s as %s" % [
      Expression.quote(@members.first),
      WindowExpression.new(&@block).to_sql
    ]
  end
end

class OrderBy < Expression
  def to_sql
    "order by %s" % @members.map { |e| Expression.quote(e) }.join(', ')
  end
end

class Limit < Expression
  def to_sql
    "limit %d" % @members[0]
  end
end

class Query
  def initialize(&block)
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
      @with,
      @select || default_select,
      @from,
      @where,
      @window,
      @order_by,
      @limit
    ].compact.map { |c| c.to_sql }.join(' ')
  end

  def default_select
    Select.new(:*)
  end

  def method_missing(sym, *args)
    super if sym == :to_hash
    if args.empty?
      Identifier.new(sym)
    else
      FunctionCall.new(sym, *args)
    end
  end

  def with(*members, **props)
    @with = With.new(*members, **props)
  end

  H_EMPTY = {}.freeze

  def select(*members, **props)
    if members.empty? && !props.empty?
      members = props.map { |k, v| Alias.new(v, k) }
      props = {}
    end
    @select = Select.new(*members, **props)
  end

  def from(*members, **props)
    @from = From.new(*members, **props)
  end

  def where(expr)
    if @where
      @where.members << expr
    else
      @where = Where.new(expr)
    end
  end

  def window(sym, &block)
    @window = Window.new(sym, &block)
  end

  def order_by(*members, **props)
    @order_by = OrderBy.new(*members, **props)
  end

  def limit(*members)
    @limit = Limit.new(*members)
  end

  def all(sym = nil)
    if sym
      Identifier.new("#{sym}.*")
    else
      Identifier.new('*')
    end
  end
end
