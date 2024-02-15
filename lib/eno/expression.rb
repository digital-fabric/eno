# frozen_string_literal: true

module Eno
  # Abstract expression class. All SQL expressions are derived from this class.
  class Expression
    attr_reader :members, :props

    # Initializes an expression with the given arguments.
    #
    # @param *members [Array] expression members
    # @param **props [Hash] expression properties
    # @return [void]
    def initialize(*members, **props)
      @members = members
      @props = props
    end

    # Returns an aliased copy of self, or self alias as the given block.
    #
    # @param sym [Symbol, String, nil] alias for self
    # @param &block [Proc, nil] block to be aliased by self
    # @return [Eno::Alias] AS expression
    def as(sym = nil, &block)
      if sym
        Alias.new(self, sym)
      else
        Alias.new(self, Query.new(&block))
      end
    end

    # Returns a `DESC` expression.
    #
    # @return [Eno::Desc] DESC expression
    def desc
      Desc.new(self)
    end

    # Returns a `OVER` expression.
    #
    # @param sym [Symbol, String, nil] OVER target
    # @param &block [Proc, nil] window expression block
    # @return [Eno::Over, Eno::WindowExpression] OVER expression
    def over(sym = nil, &block)
      Over.new(self, sym || WindowExpression.new(&block))
    end

    S_EQ    = '='
    S_TILDE = '~'
    S_NEQ   = '<>'
    S_LT    = '<'
    S_GT    = '>'
    S_LTE   = '<='
    S_GTE   = '>='
    S_AND   = 'and'
    S_OR    = 'or'
    S_PLUS  = '+'
    S_MINUS = '-'
    S_MUL   = '*'
    S_DIV   = '/'
    S_MOD   = '%'
    S_LIKE  = 'like'

    # Returns an operator expression using `==`.
    #
    # @param expr2 [any] Right hand expression
    # @return [Eno::Operator] Operator expression
    def ==(expr2)
      Operator.new(S_EQ, self, expr2)
    end

    # Returns an operator expression using `=~`.
    #
    # @param expr2 [any] Right hand expression
    # @return [Eno::Operator] Operator expression
    def =~(expr2)
      case expr2
      when String
        Operator.new(S_LIKE, self, expr2)
      when Range
        Between.new(self, expr2)
      when Array
        In.new(self, *expr2)
      when Eno::Query
        In.new(self, expr2)
      when Hash
        NamespacedHash.new(self, expr2)
      else
        Operator.new(S_EQ, self, expr2)
      end
    end

    def !~(expr2)
      !(self =~ expr2)
    end

    # Returns an operator expression using `!=`.
    #
    # @param expr2 [any] Right hand expression
    # @return [Eno::Operator] Operator expression
    def !=(expr2)
      Operator.new(S_NEQ, self, expr2)
    end

    # Returns an operator expression using `<`.
    #
    # @param expr2 [any] Right hand expression
    # @return [Eno::Operator] Operator expression
    def <(expr2)
      Operator.new(S_LT, self, expr2)
    end

    # Returns an operator expression using `>`.
    #
    # @param expr2 [any] Right hand expression
    # @return [Eno::Operator] Operator expression
    def >(expr2)
      Operator.new(S_GT, self, expr2)
    end

    # Returns an operator expression using `<=`.
    #
    # @param expr2 [any] Right hand expression
    # @return [Eno::Operator] Operator expression
    def <=(expr2)
      Operator.new(S_LTE, self, expr2)
    end

    # Returns an operator expression using `>=`.
    #
    # @param expr2 [any] Right hand expression
    # @return [Eno::Operator] Operator expression
    def >=(expr2)
      Operator.new(S_GTE, self, expr2)
    end

    # Returns an operator expression using `AND`.
    #
    # @param expr2 [any] Right hand expression
    # @return [Eno::Operator] Operator expression
    def &(expr2)
      Operator.new(S_AND, self, expr2)
    end

    ## Returns an AND expression for two or more sub-expressions.
    # @param *members [Array<any>] expressions
    # @return [Eno::Operator] AND expression
    def self.and(*members)
      Operator.new(S_AND, *members)
    end

    # Returns an operator expression using `OR`.
    #
    # @param expr2 [any] Right hand expression
    # @return [Eno::Operator] Operator expression
    def |(expr2)
      Operator.new(S_OR, self, expr2)
    end

    # Returns an operator expression using `+`.
    #
    # @param expr2 [any] Right hand expression
    # @return [Eno::Operator] Operator expression
    def +(expr2)
      Operator.new(S_PLUS, self, expr2)
    end

    # Returns an operator expression using `-`.
    #
    # @param expr2 [any] Right hand expression
    # @return [Eno::Operator] Operator expression
    def -(expr2)
      Operator.new(S_MINUS, self, expr2)
    end

    # Returns an operator expression using `*`.
    #
    # @param expr2 [any] Right hand expression
    # @return [Eno::Operator] Operator expression
    def *(expr2)
      Operator.new(S_MUL, self, expr2)
    end

    # Returns an operator expression using `/`.
    #
    # @param expr2 [any] Right hand expression
    # @return [Eno::Operator] Operator expression
    def /(expr2)
      Operator.new(S_DIV, self, expr2)
    end

    # Returns an operator expression using `%`.
    #
    # @param expr2 [any] Right hand expression
    # @return [Eno::Operator] Operator expression
    def %(expr2)
      Operator.new(S_MOD, self, expr2)
    end

    # Returns an `CAST` expression.
    #
    #     Q { select a^integer }
    #
    # @param expr2 [any] expression to cast as
    # @return [Eno::CastShorthand] CAST expression
    def ^(expr2)
      CastShorthand.new(self, expr2)
    end

    # Returns a `NOT expression`.
    #
    #     Q { select a & !b }
    #
    # @return [Eno::Not] NOT expression
    def !@
      Not.new(self)
    end

    # Returns a `IS NULL` expression.
    #
    # @return [Eno::IsNull] IS NULL expression
    def null?
      IsNull.new(self)
    end

    # Returns a `IS NOT NULL` expression.
    #
    # @return [Eno::IsNotNull] IS NOT NULL expression
    def not_null?
      IsNotNull.new(self)
    end

    # Returns a `JOIN` expression with the given arguments.
    #
    # @param sym [Symbol, String, Eno::Expression] join expression
    # @param **props [Hash] join properties
    # @return [Eno::Join] JOIN expression
    def join(sym, **props)
      Join.new(self, sym, **props)
    end

    # Returns a `JOIN` expression with the given arguments.
    #
    # @param sym [Symbol, String, Eno::Expression] join expression
    # @param **props [Hash] join properties
    # @return [Eno::Join] JOIN expression
    def inner_join(sym, **props)
      join(sym, **props.merge(type: :inner))
    end

    # Returns a `CAST` expression.
    #
    # @param sym [Symbol, String] cast type
    # @return [Eno::Cast] CAST expression
    def cast(sym)
      Cast.new(self, sym)
    end

    # Returns a `IN` expression.
    #
    # @param *args [Array] expression list
    # @return [Eno::In] IN expression
    def in(*args)
      if args.size == 1 && (range = args.first).is_a?(Range)
        return Between.new(self, range)
      end

      In.new(self, *args)
    end

    # Returns a `NOT IN` expression.
    #
    # @param *args [Array] expression list
    # @return [Eno::In] NOT IN expression
    def not_in(*args)
      if args.size == 1 && (range = args.first).is_a?(Range)
        return NotBetween.new(self, range)
      end

      NotIn.new(self, *args)
    end
  end

  ############################################################

  S_COMMA       = ', '

  # Alias expression
  class Alias < Expression
    S_AS = '%s as %s'
    def to_sql(sql)
      S_AS % [sql.quote(@members[0]), sql.quote(@members[1])]
    end
  end

  # Case expression
  class Case < Expression
    def initialize(conditions)
      @props = conditions
    end

    S_WHEN  = 'when %s then %s'
    S_ELSE  = 'else %s'
    S_CASE  = 'case %s end'
    S_SPACE = ' '

    def to_sql(sql)
      conditions = @props.inject([]) { |a, (k, v)|
        if k.is_a?(Symbol) && k == :default
          a
        else
          a << (S_WHEN % [sql.quote(k), sql.quote(v)])
        end
      }
      if default = @props[:default]
        conditions << (S_ELSE % sql.quote(default))
      end

      S_CASE % conditions.join(S_SPACE)
    end
  end

  # Cast expression
  class Cast < Expression
    S_CAST = 'cast (%s as %s)'

    def to_sql(sql)
      S_CAST % [sql.quote(@members[0]), sql.quote(@members[1])]
    end
  end

  # CastShorthand expression
  class CastShorthand < Expression
    S_CAST = '%s::%s'

    def to_sql(sql)
      S_CAST % [sql.quote(@members[0]), sql.quote(@members[1])]
    end
  end

  # Desc expression
  class Desc < Expression
    S_DESC = '%s desc'

    def to_sql(sql)
      S_DESC % sql.quote(@members[0])
    end
  end

  # Function call expression
  class FunctionCall < Expression
    S_FUN_NO_ARGS = '%s()'
    S_FUN         = '%s(%s)'

    def to_sql(sql)
      fun = @members[0]
      if @members.size == 2 && Identifier === @members.last && @members.last._empty_placeholder?
        S_FUN_NO_ARGS % fun
      else
        S_FUN % [
          fun,
          @members[1..-1].map { |a| sql.quote(a) }.join(S_COMMA)
        ]
      end
    end
  end

  # Identifier expression
  class Identifier < Expression
    def to_sql(sql)
      # "\"#{@members[0].to_sym}\""
      sql.quote(@members[0].to_sym)
    end

    def method_missing(sym)
      super if sym == :to_hash
      Identifier.new("#{@members[0]}.#{sym}")
    end

    def _empty_placeholder?
      m = @members[0]
      Symbol === m && m == :_
    end

    def json(*args, **props)
      JsonExpression.new(self, *args, **props)
    end
  end

  # In expression
  class In < Expression
    S_IN = '(%s in (%s))'

    def to_sql(sql)
      S_IN % [
        sql.quote(@members[0]),
        @members[1..-1].map { |m| sql.quote(m) }.join(S_COMMA)
      ]
    end

    def !@
      NotIn.new(*@members)
    end
  end

  # Between expression
  class Between < Expression
    S_BETWEEN = '(%s between %s and %s)'
    S_BETWEEN_EXCLUDE_END = '(%s >= %s and %s < %s)'

    def to_sql(sql)
      left = sql.quote(@members[0])
      range = @members[1]
      min = sql.quote(range.begin)
      max = sql.quote(range.end)
      if range.exclude_end?
        S_BETWEEN_EXCLUDE_END % [left, min, left, max]
      else
        S_BETWEEN % [left, min, max]
      end
    end

    def !@
      NotBetween.new(*@members)
    end
  end

  # NamedspacedHash expression
  class NamespacedHash < Expression
    def to_sql(sql)
      left, right = *@members
      case left
      when Identifier
        parts = []
        right.each do |k, v|
          parts << ((left.send(k)) =~ v).to_sql(sql)
        end
        "(#{parts.join(' and ')})"
      end
    end

    def !@
      raise 'Invalid expression'
    end
  end

  # Json expression
  class JsonExpression < Expression
    def to_sql(sql)
      func = @props[:function] || 'json_extract'

      "#{func}(#{@members[0].to_sql(sql)}, #{sql.quote(calc_path(sql))})"
    end

    def calc_path(sql)
      @members[1..-1].inject(+'$') do |path, m|
        join_path(path, m, sql)
      end
    end

    def join_path(left, right, sql)
      case right
      when /^\$/
        right
      when /^\[/
        "#{left}#{right}"
      when Integer
        "#{left}[#{right}]"
      when JsonSubscriptExpression
        "#{left}[#{right.to_sql(sql)}]"
      else
        "#{left}.#{right}"
      end
    end

    def method_missing(sym)
      JsonExpression.new(*@members, sym, **@props)
    end

    def [](subscript)
      case subscript
      when String, Symbol
        JsonExpression.new(*@members, subscript, **@props)
      else
        JsonExpression.new(*@members, JsonSubscriptExpression.new(subscript), **@props)
      end
    end
  end

  class JsonSubscriptExpression < Expression
    def to_sql(sql)
      case (subscript = @members.first)
      when Expression
        subscript.to_sql(sql)
      else
        sql.quote(subscript)
      end
    end
  end

  # IsNotNull expression
  class IsNotNull < Expression
    S_NOT_NULL = '(%s is not null)'
    def to_sql(sql)
      S_NOT_NULL % sql.quote(@members[0])
    end
  end

  # IsNull expression
  class IsNull < Expression
    S_NULL = '(%s is null)'

    def to_sql(sql)
      S_NULL % sql.quote(@members[0])
    end

    def !@
      IsNotNull.new(@members[0])
    end
  end

  # Join expression
  class Join < Expression
    H_JOIN_TYPES = {
      nil:    'join',
      inner:  'inner join',
      outer:  'outer join'
    }

    S_JOIN  = '%s %s %s %s'
    S_ON    = 'on %s'
    S_USING = 'using (%s)'

    def to_sql(sql)
      (
        S_JOIN % [
          sql.quote(@members[0]),
          H_JOIN_TYPES[@props[:type]],
          sql.quote(@members[1]),
          condition_sql(sql)
        ]
      ).strip
    end

    def condition_sql(sql)
      if @props[:on]
        S_ON % sql.quote(@props[:on])
      elsif using_fields = @props[:using]
        fields = using_fields.is_a?(Array) ? using_fields : [using_fields]
        S_USING % fields.map { |f| sql.quote(f) }.join(S_COMMA)
      else
        nil
      end
    end
  end

  # Literal expression
  class Literal < Expression
    def to_sql(sql)
      sql.quote(@members[0])
    end
  end

  # Operator expression
  class Operator < Expression
    attr_reader :op

    def initialize(op, *members, **props)
      if Operator === members[0] && op == members[0].op
        members = members[0].members + members[1..-1]
      end
      if Operator === members.last && op == members.last.op
        members = members[0..-2] + members.last.members
      end

      super(*members, **props)
      @op = op
    end

    S_OP = ' %s '
    S_OP_EXPR = '(%s)'

    def to_sql(sql)
      op_s = S_OP % @op
      S_OP_EXPR % @members.map { |m| sql.quote(m) }.join(op_s)
    end

    INVERSE_OP = {
      '='   => '<>',
      '<>'  => '=',
      '<'   => '>=',
      '>'   => '<=',
      '<='  => '>',
      '>='  => '<',
      'like' => 'not like'
    }

    def !@
      inverse = INVERSE_OP[@op]
      inverse ? Operator.new(inverse, *@members) : super
    end
  end

  # Over expression
  class Over < Expression
    S_OVER = '%s over %s'

    def to_sql(sql)
      S_OVER % [sql.quote(@members[0]), sql.quote(@members[1])]
    end
  end

  # Not expression
  class Not < Expression
    S_NOT = '(not %s)'

    def to_sql(sql)
      S_NOT % sql.quote(@members[0])
    end
  end

  # NotIn expression
  class NotIn < Expression
    S_NOT_IN  = '(%s not in (%s))'

    def to_sql(sql)
      S_NOT_IN % [
        sql.quote(@members[0]),
        @members[1..-1].map { |m| sql.quote(m) }.join(S_COMMA)
      ]
    end
  end

  # NotBetween expression
  class NotBetween < Expression
    S_NOT_BETWEEN  = '(%s not between %s and %s)'
    S_NOT_BETWEEN_EXCLUDE_END = '(%s < %s or %s >= %s)'

    def to_sql(sql)
      left = sql.quote(@members[0])
      range = @members[1]
      min = sql.quote(range.begin)
      max = sql.quote(range.end)
      if range.exclude_end?
        S_NOT_BETWEEN_EXCLUDE_END % [left, min, left, max]
      else
        S_NOT_BETWEEN % [left, min, max]
      end
    end
  end

  # Window expression
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

    S_UNBOUNDED     = 'between unbounded preceding and unbounded following'
    S_WINDOW        = '(%s)'
    S_PARTITION_BY  = 'partition by %s '
    S_ORDER_BY      = 'order by %s '
    S_BETWEEN         = 'range %s '

    def range_unbounded
      @range = S_UNBOUNDED
    end

    def to_sql(sql)
      S_WINDOW % [
        _partition_by_clause(sql),
        _order_by_clause(sql),
        _range_clause(sql)
      ].join.strip
    end

    def _partition_by_clause(sql)
      return nil unless @partition_by
      S_PARTITION_BY % @partition_by.map { |e| sql.quote(e) }.join(S_COMMA)
    end

    def _order_by_clause(sql)
      return nil unless @order_by
      S_ORDER_BY % @order_by.map { |e| sql.quote(e) }.join(S_COMMA)
    end

    def _range_clause(sql)
      return nil unless @range
      S_BETWEEN % @range
    end

    def method_missing(sym)
      super if sym == :to_hash
      Identifier.new(sym)
    end
  end

  ############################################################

  # Combination expression
  class Combination < Expression
    S_COMBINATION     = ' %s '
    S_COMBINATION_ALL = ' %s all '

    def to_sql(sql)
      union = (@props[:all] ? S_COMBINATION_ALL : S_COMBINATION) % @props[:kind]
      @members.map { |m| sql.quote(m) }.join(union)
    end
  end

  # From expression
  class From < Expression
    S_FROM  = 'from %s'
    S_T1    = '%s t1'
    S_ALIAS = '%s %s'

    def to_sql(sql)
      S_FROM % @members.map { |m| member_sql(m, sql) }.join(S_COMMA)
    end

    def member_sql(member, sql)
      if Query === member
        S_T1 % sql.quote(member)
      elsif Alias === member && Query === member.members[0]
        S_ALIAS % [sql.quote(member.members[0]), sql.quote(member.members[1])]
      else
        sql.quote(member)
      end
    end
  end

  # Limit expression
  class Limit < Expression
    S_LIMIT = 'limit %d'

    def to_sql(sql)
      S_LIMIT % @members[0]
    end
  end

  # OrderBy expression
  class OrderBy < Expression
    S_ORDER_BY = 'order by %s'

    def to_sql(sql)
      S_ORDER_BY % @members.map { |e| sql.quote(e) }.join(S_COMMA)
    end
  end

  class GroupBy < Expression
    S_GROUP_BY = 'group by %s'

    def to_sql(sql)
      S_GROUP_BY % @members.map { |e| sql.quote(e) }.join(S_COMMA)
    end
  end

  # Select expression
  class Select < Expression
    S_SELECT              = 'select %s%s'
    S_DISTINCT            = 'distinct '
    S_DISTINCT_ON         = 'distinct on (%s) '
    S_DISTINCT_ON_SINGLE  = 'distinct on %s '

    def to_sql(sql)
      S_SELECT % [
        distinct_clause(sql), @members.map { |e| sql.quote(e) }.join(S_COMMA)
      ]
    end

    def distinct_clause(sql)
      case (on = @props[:distinct])
      when nil
        nil
      when true
        S_DISTINCT
      when Array
        S_DISTINCT_ON % on.map { |e| sql.quote(e) }.join(S_COMMA)
      else
        S_DISTINCT_ON_SINGLE % sql.quote(on)
      end
    end
  end

  # Where expression
  class Where < Expression
    S_WHERE = 'where %s'
    S_AND   = ' and '

    def to_sql(sql)
      S_WHERE % @members.map { |e| sql.quote(e) }.join(S_AND)
    end
  end

  # Window expression
  class Window < Expression
    def initialize(sym, &block)
      super(sym)
      @block = block
    end

    S_WINDOW  = 'window %s as %s'

    def to_sql(sql)
      S_WINDOW % [
        sql.quote(@members.first),
        WindowExpression.new(&@block).to_sql(sql)
      ]
    end
  end

  # With expression
  class With < Expression
    S_WITH    = 'with %s'

    def to_sql(sql)
      S_WITH % @members.map { |e| sql.quote(e) }.join(S_COMMA)
    end
  end
end
