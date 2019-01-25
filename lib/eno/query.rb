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

  def union(&block)
    Query.new(@ctx) {
      union Query.new(&block)
    }
  end
end
