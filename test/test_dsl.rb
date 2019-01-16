# frozen_string_literal: true

require 'modulation'
require 'minitest/autorun'

Eno = import '../lib/eno'

T = MiniTest::Test
class T
  def assert_sql(sql, &block); assert_equal(sql, Q(&block).to_sql); end
end

class SelectTest < T
  def test_that_no_from_select_is_supported
    assert_sql('select 1') { select 1 }
    assert_sql('select pg_sleep(1)') { select pg_sleep(1) }
  end

  def test_that_select_with_hash_is_supported
    assert_sql('select 1 as a, 2 as b') { select a: 1, b: 2 }
    assert_sql('select pg_sleep(1) as s, pg_sleep(2) as s2') {
      select s: pg_sleep(1), s2: pg_sleep(2)
    }
  end

  def test_that_select_accepts_aliases
    assert_sql('select 1 as c') { select _q(1).as c }
    assert_sql('select a as b') { select a.as b }
    assert_sql('select a as b, c as d') { select (a.as b), (c.as d) }
  end

  def test_that_function_expressions_can_be_aliased
    assert_sql('select pg_sleep(1) as s, pg_sleep(2) as s2') {
      select pg_sleep(1).as(s), pg_sleep(2).as(s2)
    }
  end

  def test_that_aliases_can_be_expressed_with_symbols
    assert_sql('select pg_sleep(1) as s, pg_sleep(2) as s2') {
      select pg_sleep(1).as(:s), pg_sleep(2).as(:s2)
    }
  end

  def test_that_select_accepts_qualified_names
    assert_sql('select a.b, c.d as e') {
      select a.b, c.d.as(e)
    }

    assert_sql('select a.b.c.d') {
      select a.b.c.d
    }
  end
  
  def test_select_distinct
    assert_sql('select distinct a, b') {
      select_distinct a, b
    }
  end
end

class FromTest < T
  def test_that_from_accepts_table_name
    assert_sql('select * from abc') {
      from abc
    }
  end

  def test_that_expression_can_be_aliased
    assert_sql('select * from abc as a') {
      from abc.as(a)
    }
  end

  def test_that_from_accepts_sub_query
    query = Q { select _q(1).as a }
    assert_sql('select a from (select 1 as a) t1') {
      select a
      from query
    }

    assert_sql('select a from (select 1 as a) t3') {
      select a
      from query.as t3
    }
  end
end

class WithTest < T
  def test_that_with_accepts_sub_queries
    assert_sql('with t1 as (select 1 as a), t2 as (select 2 as b) select * from b') {
      with t1.as { select _q(1).as a }, t2.as { select _q(2).as b }
      select all
      from b
    }
  end
end

class WhereTest < T
  def test_that_where_accepts_boolean_const
    assert_sql('select * from a where true') {
      from a
      where true
    }
  end

  def test_that_where_accepts_comparison_expression
    assert_sql('select * from a where (b = 1)') {
      from a
      where b == 1
    }

    assert_sql('select * from a where ((b = 1) and (c = 2))') {
      from a
      where (b == 1) & (c == 2)
    }

    assert_sql('select * from a where ((b > 1) and (c < 2))') {
      from a
      where (b > 1) & (c < 2)
    }

    assert_sql('select * from a where ((b <= 1) and (c <> 2))') {
      from a
      where (b <= 1) & (c != 2)
    }
  end

  def test_that_where_accepts_logical_expression
    assert_sql('select * from a where (b and c)') {
      from a
      where b & c
    }

    assert_sql('select * from a where (b or c)') {
      from a
      where b | c
    }

    assert_sql('select * from a where (b and (not c))') {
      from a
      where b & _not(c)
    }
  end

  def test_that_where_accepts_nil
    assert_sql('select * from a where (b is null)') {
      from a
      where b.null?
    }

    assert_sql('select * from a where (b is not null)') {
      from a
      where _not(b.null?)
    }
  end

  def test_that_where_accepts_arithmetic_operators
    assert_sql('select * from a where ((b + c) = 42)') {
      from a
      where b + c == 42
    }
  end
end

class Eno::Identifier
  def [](sym)
    sym = sym.expr.to_s if Eno::Expression === sym
    
    case sym
    when Symbol
      Eno::Alias.new(JSONBExpression.new(self, sym.to_s), sym)
    else
      JSONBExpression.new(self, sym.to_s)
    end
  end
end

class JSONBExpression < Eno::Expression
  def initialize(column, field)
    @column = column
    @field = field
  end

  def to_sql
    "#{_quote(@column)}->>#{_quote(@field.to_s)}"
  end
end

class DSLTest < T
  def test_that_dsl_can_be_extended
    assert_sql("select attributes->>'path'") {
      a = attributes[path]
      select a#attributes[path]
    }

    assert_sql("select attributes->>'path' as path") {
      select attributes[:path]
    }
  end
end

class WindowTest < T
  def test_that_over_is_supported
    assert_sql('select last_value(q) over w as q_last, last_value(v) over w as v_last') {
      select last_value(q).over(w).as(q_last),
             last_value(v).over(w).as(v_last)
    }
  end

  def test_that_over_supports_inline_window
    assert_sql('select group_name, avg(price) over (partition by group_name) from products') {
      select group_name, (avg(price).over { partition_by group_name })
      from products
    }
  end

  def test_named_windows
    assert_sql('select last_value(q) over w as q_last, last_value(v) over w as v_last from t1 window w as (partition by stamp_aligned order by stamp range between unbounded preceding and unbounded following)') {
      select last_value(q).over(w).as(q_last),
             last_value(v).over(w).as(v_last)
      from t1
      window(w) {
        partition_by stamp_aligned
        order_by stamp
        range_unbounded
      }
    }
  end
end

class Eno::Query
  def extract_epoch_from(sym)
    ExtractEpoch.new(sym)
  end
end

class ExtractEpoch < Eno::Expression
  def to_sql
    "extract (epoch from #{_quote(@expr)})::integer"
  end
end

class UseCasesTest < T
  def test_use_case_1
    assert_sql("select extract (epoch from stamp)::integer as stamp, quality, value, unformatted_value, datatype from states where (((path = '/r1') and (stamp >= '2019-01-01 00:00:00+00')) and (stamp < '2019-01-02 00:00:00+00')) order by stamp desc limit 1") {
      select extract_epoch_from(stamp).as(stamp), quality, value, unformatted_value, datatype
      from states
      where (path == '/r1') & (stamp >= '2019-01-01 00:00:00+00') & (stamp < '2019-01-02 00:00:00+00')
      order_by stamp.desc
      limit 1
    }
  end
end