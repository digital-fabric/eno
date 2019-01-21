# frozen_string_literal: true

Expressions = import('./expressions')
SQL         = import('./sql')

export_default :Query

class Query
  def initialize(**ctx, &block)
    @ctx = ctx
    @block = block
  end

  def to_sql(**ctx)
    r = SQL.new(@ctx.merge(ctx))
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
end
