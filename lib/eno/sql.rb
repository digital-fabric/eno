# frozen_string_literal: true

Expressions = import('./expressions')

export_default :SQL

class SQL
  def initialize(ctx)
    @ctx = ctx
  end

  def to_sql(&block)
    instance_eval(&block)
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

  def _q(expr)
    Expressions::QuotedExpression.new(expr)
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
end
