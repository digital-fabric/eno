# frozen_string_literal: true

Expressions = import('./expressions')
Query = import('./query')

export :SQL

class SQL
  def initialize(ctx)
    @ctx = ctx
  end

  def to_sql(&block)
    instance_eval(&block)

    return @combination.to_sql(self) if @combination

    [
      @with,
      @select || default_select,
      @from,
      @where,
      @window,
      @order_by,
      @limit
    ].compact.map { |c| c.to_sql(self) }.join(' ')
  end

  def quote(expr)
    case expr
    when Query::Query
      "(#{expr.to_sql(@ctx).strip})"
    when Expressions::Expression
      expr.to_sql(self)
    when Symbol
      expr.to_s
    when String
      "'#{expr}'"
    else
      expr.inspect
    end
  end

  def context
    @ctx
  end

  def _l(value)
    Expressions::Literal.new(value)
  end

  def _i(value)
    Expressions::Identifier.new(value)
  end

  def default_select
    Expressions::Select.new(:*)
  end

  def method_missing(sym, *args)
    if @ctx.has_key?(sym)
      value = @ctx[sym]
      return Symbol === value ? Expressions::Identifier.new(value) : value
    end
    
    super if sym == :to_hash
    if args.empty?
      Expressions::Identifier.new(sym)
    else
      Expressions::FunctionCall.new(sym, *args)
    end
  end

  def with(*members, **props)
    @with = Expressions::With.new(*members, **props)
  end

  H_EMPTY = {}.freeze

  def select(*members, **props)
    if members.empty? && !props.empty?
      members = props.map { |k, v| Expressions::Alias.new(v, k) }
      props = {}
    end
    @select = Expressions::Select.new(*members, **props)
  end

  def from(*members, **props)
    @from = Expressions::From.new(*members, **props)
  end

  def where(expr)
    if @where
      @where.members << expr
    else
      @where = Expressions::Where.new(expr)
    end
  end

  def window(sym, &block)
    @window = Expressions::Window.new(sym, &block)
  end

  def order_by(*members, **props)
    @order_by = Expressions::OrderBy.new(*members, **props)
  end

  def limit(*members)
    @limit = Expressions::Limit.new(*members)
  end

  def all(sym = nil)
    if sym
      Expressions::Identifier.new("#{sym}.*")
    else
      Expressions::Identifier.new('*')
    end
  end

  def cond(props)
    Expressions::Case.new(props)
  end

  def default
    :default
  end

  def union(*queries, **props)
    @combination = Expressions::Combination.new(*queries, kind: :union, **props)
  end

  def intersect(*queries, **props)
    @combination = Expressions::Combination.new(*queries, kind: :intersect, **props)
  end

  def except(*queries, **props)
    @combination = Expressions::Combination.new(*queries, kind: :except, **props)
  end
end
