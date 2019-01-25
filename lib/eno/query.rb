# frozen_string_literal: true

export :Query

Expressions = import('./expressions')
SQL         = import('./sql')

class Query
  def initialize(**ctx, &block)
    @ctx = ctx
    @block = block
  end

  def to_sql(**ctx)
    r = SQL::SQL.new(@ctx.merge(ctx))
    r.to_sql(&@block)
  end

  def as(sym)
    Expressions::Alias.new(self, sym)
  end

  def where(&block)
    old_block = @block
    Query.new(@ctx) {
      instance_eval(&old_block)
      where instance_eval(&block)
    }
  end

  def mutate(&block)
    old_block = @block
    Query.new(@ctx) {
      instance_eval(&old_block)
      instance_eval(&block)
    }
  end

  def union(*queries, **props, &block)
    q1 = self
    queries << Query.new(&block) if queries.empty?
    Query.new(@ctx) { union q1, *queries, **props }
  end
  alias_method :|, :union

  def union_all(*queries, &block)
    union(*queries, all: true, &block)
  end

  def intersect(*queries, **props, &block)
    q1 = self
    queries << Query.new(&block) if queries.empty?
    Query.new(@ctx) { intersect q1, *queries, **props }
  end
  alias_method :&, :intersect

  def intersect_all(*queries, &block)
    intersect(*queries, all: true, &block)
  end

  def except(*queries, **props, &block)
    q1 = self
    queries << Query.new(&block) if queries.empty?
    Query.new(@ctx) { except q1, *queries, **props }
  end
  alias_method :"^", :except

  def except_all(*queries, &block)
    except(*queries, all: true, &block)
  end
end
