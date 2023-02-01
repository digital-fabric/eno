# frozen_string_literal: true

module Eno
  # Query represents an SQL query.
  class Query
    # Initializes a new query.
    #
    # @param **ctx [Hash] query context values
    # @param &block [Proc] query code
    # @return [void]
    def initialize(**ctx, &block)
      @ctx = ctx
      @block = block
    end
    
    # Renders the query as an SQL statement.
    #
    # @param escape_proc [Proc, nil] proc for escaping literal strings
    # @param **ctx [Hash] query context values
    # @return [String] SQL string
    def to_sql(escape_proc: nil, **ctx)
      r = SQL.new(escape_proc: escape_proc, **@ctx.merge(ctx))
      r.to_sql(&@block)
    end
    
    # Adds an alias to the query when used as a subquery.
    #
    # @param sym [Symbol, String] subquery alias
    # @return [Eno::Alias] aliased query
    def as(sym)
      Alias.new(self, sym)
    end
    
    # Adds where conditions to the query.
    #
    # @param &block [Proc] where block
    # @return [Eno::Query] modified query
    def where(&block)
      old_block = @block
      Query.new(**@ctx) {
        instance_eval(&old_block)
        where instance_eval(&block)
      }
    end
    
    # Mutates the query by executing the given block and returning the modified
    # query.
    #
    # @param &block [Proc] query code
    # @return [Eno::Query] modified query
    def mutate(&block)
      old_block = @block
      Query.new(**@ctx) {
        instance_eval(&old_block)
        instance_eval(&block)
      }
    end
    
    # Returns a `UNION` expression between self and one or more other queries. The
    # additional query or queries for the union expression can be specified as
    # arguments or as a block:
    #
    #     # as arguments
    #     q1.union(q2, q3)
    #
    #     # as a block
    #     Q { from foo }.union { from bar }
    #
    # @param *queries [Array] queries for union
    # @param **props [Hash] union properties
    # @param &block [Proc] alternative additional query
    # @return [Eno::Combination] union expression
    def union(*queries, **props, &block)
      q1 = self
      queries << Query.new(&block) if queries.empty?
      Query.new(**@ctx) { union q1, *queries, **props }
    end
    alias_method :|, :union
    
    # Returns a `UNION ALL` expression between self and one or more other queries.
    # The additional query or queries for the union expression can be specified
    # as arguments or as a block.
    #
    # @param *queries [Array] queries for union
    # @param **props [Hash] union properties
    # @param &block [Proc] alternative additional query
    # @return [Eno::Combination] union expression
    def union_all(*queries, &block)
      union(*queries, all: true, &block)
    end
    
    # Returns a `INTERSECT` expression between self and one or more other
    # queries. The additional query or queries for the intersect expression can
    # be specified as arguments or as a block.
    #
    # @param *queries [Array] queries for intersect
    # @param **props [Hash] intersect properties
    # @param &block [Proc] alternative additional query
    # @return [Eno::Combination] intersect expression
    def intersect(*queries, **props, &block)
      q1 = self
      queries << Query.new(&block) if queries.empty?
      Query.new(**@ctx) { intersect q1, *queries, **props }
    end
    alias_method :&, :intersect
    
    # Returns a `INTERSECT ALL` expression between self and one or more other
    # queries. The additional query or queries for the intersect expression can be
    # specified as arguments or as a block.
    #
    # @param *queries [Array] queries for intersect
    # @param &block [Proc] alternative additional query
    # @return [Eno::Combination] intersect expression
    def intersect_all(*queries, &block)
      intersect(*queries, all: true, &block)
    end
    
    # Returns a `EXCEPT` expression between self and one or more other queries.
    # The additional query or queries for the except expression can be specified
    # as arguments or as a block.
    #
    # @param *queries [Array] queries for except
    # @param &block [Proc] alternative additional query
    # @return [Eno::Combination] except expression
    def except(*queries, **props, &block)
      q1 = self
      queries << Query.new(&block) if queries.empty?
      Query.new(**@ctx) { except q1, *queries, **props }
    end
    alias_method :"^", :except
    
    # Returns a `EXCEPT ALL` expression between self and one or more other queries.
    # The additional query or queries for the except expression can be specified
    # as arguments or as a block.
    #
    # @param *queries [Array] queries for except
    # @param &block [Proc] alternative additional query
    # @return [Eno::Combination] except expression
    def except_all(*queries, &block)
      except(*queries, all: true, &block)
    end
  end
end
