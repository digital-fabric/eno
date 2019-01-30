# frozen_string_literal: true

export  :Expression,
        
        :Alias,
        :Case,
        :Cast,
        :CastShorthand,
        :Desc,
        :FunctionCall,
        :Identifier,
        :In,
        :IsNotNull,
        :IsNull,
        :Join,
        :Literal,
        :Operator,
        :Over,
        :Not,
        :NotIn,
        :WindowExpression,

        :Combination,
        :From,
        :Limit,
        :OrderBy,
        :Select,
        :Where,
        :Window,
        :With

Query = import('./query')

class Expression
  attr_reader :members, :props

  def initialize(*members, **props)
    @members = members
    @props = props
  end

  def as(sym = nil, &block)
    if sym
      Alias.new(self, sym)
    else
      Alias.new(self, Query::Query.new(&block))
    end
  end

  def desc
    Desc.new(self)
  end

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

  def ==(expr2)
    Operator.new(S_EQ, self, expr2)
  end

  def =~(expr2)
    Operator.new(S_TILDE, self, expr2)
  end

  def !=(expr2)
    Operator.new(S_NEQ, self, expr2)
  end

  def <(expr2)
    Operator.new(S_LT, self, expr2)
  end

  def >(expr2)
    Operator.new(S_GT, self, expr2)
  end

  def <=(expr2)
    Operator.new(S_LTE, self, expr2)
  end

  def >=(expr2)
    Operator.new(S_GTE, self, expr2)
  end

  def &(expr2)
    Operator.new(S_AND, self, expr2)
  end

  def |(expr2)
    Operator.new(S_OR, self, expr2)
  end

  def +(expr2)
    Operator.new(S_PLUS, self, expr2)
  end

  def -(expr2)
    Operator.new(S_MINUS, self, expr2)
  end

  def *(expr2)
    Operator.new(S_MUL, self, expr2)
  end

  def /(expr2)
    Operator.new(S_DIV, self, expr2)
  end

  def %(expr2)
    Operator.new(S_MOD, self, expr2)
  end

  def ^(expr2)
    CastShorthand.new(self, expr2)
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

  def cast(sym)
    Cast.new(self, sym)
  end

  def in(*args)
    In.new(self, *args)
  end

  def not_in(*args)
    NotIn.new(self, *args)
  end
end

############################################################

S_COMMA       = ', '

class Alias < Expression
  S_AS = '%s as %s'
  def to_sql(sql)
    S_AS % [sql.quote(@members[0]), sql.quote(@members[1])]
  end
end

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

class Cast < Expression
  S_CAST = 'cast (%s as %s)'

  def to_sql(sql)
    S_CAST % [sql.quote(@members[0]), sql.quote(@members[1])]
  end
end

class CastShorthand < Expression
  S_CAST = '%s::%s'

  def to_sql(sql)
    S_CAST % [sql.quote(@members[0]), sql.quote(@members[1])]
  end
end

class Desc < Expression
  S_DESC = '%s desc'

  def to_sql(sql)
    S_DESC % sql.quote(@members[0])
  end
end

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

class Identifier < Expression
  def to_sql(sql)
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
end

class In < Expression
  S_IN    = '%s in (%s)'

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

class IsNotNull < Expression
  S_NOT_NULL = '(%s is not null)'
  def to_sql(sql)
    S_NOT_NULL % sql.quote(@members[0])
  end
end

class IsNull < Expression
  S_NULL = '(%s is null)'

  def to_sql(sql)
    S_NULL % sql.quote(@members[0])
  end

  def !@
    IsNotNull.new(@members[0])
  end
end

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
    (S_JOIN % [
      sql.quote(@members[0]),
      H_JOIN_TYPES[@props[:type]],
      sql.quote(@members[1]),
      condition_sql(sql)
    ]).strip
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

class Literal < Expression
  def to_sql(sql)
    sql.quote(@members[0])
  end
end

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
    '>='  => '<'
  }

  def !@
    inverse = INVERSE_OP[@op]
    inverse ? Operator.new(inverse, *@members) : super
  end
end

class Over < Expression
  S_OVER = '%s over %s'

  def to_sql(sql)
    S_OVER % [sql.quote(@members[0]), sql.quote(@members[1])]
  end
end

class Not < Expression
  S_NOT = '(not %s)'

  def to_sql(sql)
    S_NOT % sql.quote(@members[0])
  end
end

class NotIn < Expression
  S_NOT_IN  = '%s not in (%s)'

  def to_sql(sql)
    S_NOT_IN % [
      sql.quote(@members[0]),
      @members[1..-1].map { |m| sql.quote(m) }.join(S_COMMA)
    ]
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

  S_UNBOUNDED     = 'between unbounded preceding and unbounded following'
  S_WINDOW        = '(%s)'
  S_PARTITION_BY  = 'partition by %s '
  S_ORDER_BY      = 'order by %s '
  S_RANGE         = 'range %s '

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
    S_RANGE % @range
  end

  def method_missing(sym)
    super if sym == :to_hash
    Identifier.new(sym)
  end
end

############################################################

class Combination < Expression
  S_COMBINATION     = ' %s '
  S_COMBINATION_ALL = ' %s all '

  def to_sql(sql)
    union = (@props[:all] ? S_COMBINATION_ALL : S_COMBINATION) % @props[:kind]
    @members.map { |m| sql.quote(m) }.join(union)
  end
end

class From < Expression
  S_FROM  = 'from %s'
  S_T1    = '%s t1'
  S_ALIAS = '%s %s'

  def to_sql(sql)
    S_FROM % @members.map { |m| member_sql(m, sql) }.join(S_COMMA)
  end

  def member_sql(member, sql)
    if Query::Query === member
      S_T1 % sql.quote(member)
    elsif Alias === member && Query::Query === member.members[0]
      S_ALIAS % [sql.quote(member.members[0]), sql.quote(member.members[1])]
    else
      sql.quote(member)
    end
  end
end

class Limit < Expression
  S_LIMIT = 'limit %d'

  def to_sql(sql)
    S_LIMIT % @members[0]
  end
end

class OrderBy < Expression
  S_ORDER_BY = 'order by %s'

  def to_sql(sql)
    S_ORDER_BY % @members.map { |e| sql.quote(e) }.join(S_COMMA)
  end
end

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

class Where < Expression
  S_WHERE = 'where %s'
  S_AND   = ' and '

  def to_sql(sql)
    S_WHERE % @members.map { |e| sql.quote(e) }.join(S_AND)
  end
end

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

class With < Expression
  S_WITH    = 'with %s'

  def to_sql(sql)
    S_WITH % @members.map { |e| sql.quote(e) }.join(S_COMMA)
  end
end
