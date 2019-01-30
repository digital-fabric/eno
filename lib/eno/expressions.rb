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

  def ==(expr2)
    Operator.new('=', self, expr2)
  end

  def =~(expr2)
    Operator.new('~', self, expr2)
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

class Alias < Expression
  def to_sql(sql)
    "#{sql.quote(@members[0])} as #{sql.quote(@members[1])}"
  end
end

class Case < Expression
  def initialize(conditions)
    @props = conditions
  end

  def to_sql(sql)
    conditions = @props.inject([]) { |a, (k, v)|
      if k.is_a?(Symbol) && k == :default
        a
      else
        a << "when #{sql.quote(k)} then #{sql.quote(v)}"
      end
    }
    if default = @props[:default]
      conditions << "else #{sql.quote(default)}"
    end

    'case %s end' % conditions.join(' ')
  end
end

class Cast < Expression
  def to_sql(sql)
    "cast (#{sql.quote(@members[0])} as #{sql.quote(@members[1])})"
  end
end

class CastShorthand < Expression
  def to_sql(sql)
    "#{sql.quote(@members[0])}::#{sql.quote(@members[1])}"
  end
end

class Desc < Expression
  def to_sql(sql)
    "#{sql.quote(@members[0])} desc"
  end
end

class FunctionCall < Expression
  def to_sql(sql)
    fun = @members[0]
    if @members.size == 2 && Identifier === @members.last && @members.last._empty_placeholder?
      "#{fun}()"
    else
      "#{fun}(#{@members[1..-1].map { |a| sql.quote(a) }.join(', ')})"
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
  def to_sql(sql)
    "%s in (%s)" % [
      sql.quote(@members[0]),
      @members[1..-1].map { |m| sql.quote(m) }.join(', ')
    ]
  end

  def !@
    NotIn.new(*@members)
  end
end

class IsNotNull < Expression
  def to_sql(sql)
    "(#{sql.quote(@members[0])} is not null)"
  end
end

class IsNull < Expression
  def to_sql(sql)
    "(#{sql.quote(@members[0])} is null)"
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

  def to_sql(sql)
    ("%s %s %s %s" % [
      sql.quote(@members[0]),
      H_JOIN_TYPES[@props[:type]],
      sql.quote(@members[1]),
      condition_sql(sql)
    ]).strip
  end

  def condition_sql(sql)
    if @props[:on]
      'on %s' % sql.quote(@props[:on])
    elsif using_fields = @props[:using]
      fields = using_fields.is_a?(Array) ? using_fields : [using_fields]
      'using (%s)' % fields.map { |f| sql.quote(f) }.join(', ')
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

  def to_sql(sql)
    op_s = " #{@op} "
    "(%s)" % @members.map { |m| sql.quote(m) }.join(op_s)
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
  def to_sql(sql)
    "#{sql.quote(@members[0])} over #{sql.quote(@members[1])}"
  end
end

class Not < Expression
  def to_sql(sql)
    "(not #{sql.quote(@members[0])})"
  end
end

class NotIn < Expression
  def to_sql(sql)
    "%s not in (%s)" % [
      sql.quote(@members[0]),
      @members[1..-1].map { |m| sql.quote(m) }.join(', ')
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

  def range_unbounded
    @range = 'between unbounded preceding and unbounded following'
  end

  def to_sql(sql)
    "(%s)" % [
      _partition_by_clause(sql),
      _order_by_clause(sql),
      _range_clause(sql)
    ].join.strip
  end

  def _partition_by_clause(sql)
    return nil unless @partition_by
    "partition by %s " % @partition_by.map { |e| sql.quote(e) }.join(', ')
  end

  def _order_by_clause(sql)
    return nil unless @order_by
    "order by %s " % @order_by.map { |e| sql.quote(e) }.join(', ')
  end

  def _range_clause(sql)
    return nil unless @range
    "range #{@range} "
  end

  def method_missing(sym)
    super if sym == :to_hash
    Identifier.new(sym)
  end
end

############################################################

class Combination < Expression
  def to_sql(sql)
    union = @props[:all] ? " #{@props[:kind]} all " : " #{@props[:kind]} "
    @members.map { |m| sql.quote(m) }.join(union)
  end
end

class From < Expression
  def to_sql(sql)
    "from %s" % @members.map { |m| member_sql(m, sql) }.join(', ')
  end

  def member_sql(member, sql)
    if Query::Query === member
      "%s t1" % sql.quote(member)
    elsif Alias === member && Query::Query === member.members[0]
      "%s %s" % [sql.quote(member.members[0]), sql.quote(member.members[1])]
    else
      sql.quote(member)
    end
  end
end

class Limit < Expression
  def to_sql(sql)
    "limit %d" % @members[0]
  end
end

class OrderBy < Expression
  def to_sql(sql)
    "order by %s" % @members.map { |e| sql.quote(e) }.join(', ')
  end
end

class Select < Expression
  def to_sql(sql)
    "select %s%s" % [
      distinct_clause(sql), @members.map { |e| sql.quote(e) }.join(', ')
    ]
  end

  def distinct_clause(sql)
    case (on = @props[:distinct])
    when nil
      nil
    when true
      "distinct "
    when Array
      "distinct on (%s) "  % on.map { |e| sql.quote(e) }.join(', ')
    else
      "distinct on %s "  % sql.quote(on)
    end
  end
end

class Where < Expression
  def to_sql(sql)
    "where %s" % @members.map { |e| sql.quote(e) }.join(' and ')
  end
end

class Window < Expression
  def initialize(sym, &block)
    super(sym)
    @block = block
  end

  def to_sql(sql)
    "window %s as %s" % [
      sql.quote(@members.first),
      WindowExpression.new(&@block).to_sql(sql)
    ]
  end
end

class With < Expression
  def to_sql(sql)
    "with %s" % @members.map { |e| sql.quote(e) }.join(', ')
  end
end
