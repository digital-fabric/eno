# frozen_string_literal: true

S_SPACE         = ' '
S_PARENS        = '(%s)'
S_QUOTES        = "'%s'"
S_ALL           = '*'
S_QUALIFIED_ALL = '%s.*'

module Eno
  class SQL
    def initialize(escape_proc: nil, **ctx)
      @escape_proc = escape_proc
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
      ].compact.map { |c| c.to_sql(self) }.join(S_SPACE)
    end
    
    def quote(expr)
      if @escape_proc
        value = @escape_proc.(expr)
        return value if value
      end
      
      case expr
      when Query
        S_PARENS % expr.to_sql(**@ctx).strip
      when Expression
        expr.to_sql(self)
      when Symbol
        expr.to_s
      when String
        S_QUOTES % expr
      else
        expr.inspect
      end
    end
    
    def context
      @ctx
    end
    
    def _l(value)
      Literal.new(value)
    end
    
    def _i(value)
      Identifier.new(value)
    end
    
    def default_select
      Select.new(:*)
    end
    
    def method_missing(sym, *args)
      if @ctx.has_key?(sym)
        value = @ctx[sym]
        return Symbol === value ? Identifier.new(value) : value
      end
      
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
        Identifier.new(S_QUALIFIED_ALL % sym)
      else
        Identifier.new(S_ALL)
      end
    end
    
    def cond(props)
      Case.new(props)
    end
    
    def default
      :default
    end
    
    def union(*queries, **props)
      @combination = Combination.new(*queries, kind: :union, **props)
    end
    
    def intersect(*queries, **props)
      @combination = Combination.new(*queries, kind: :intersect, **props)
    end
    
    def except(*queries, **props)
      @combination = Combination.new(*queries, kind: :except, **props)
    end
  end
end
