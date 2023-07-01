# frozen_string_literal: true

require_relative './helper'

class SelectTest < MiniTest::Test
  def test_that_no_from_select_is_supported
    assert_sql('select 1') { select 1 }
    assert_sql('select pg_sleep(1)') { select pg_sleep(1) }
  end

  def test_default_select
    assert_sql('select *') { }
    assert_sql('select * from t') { from t}
  end

  def test_that_select_with_hash_is_supported
    assert_sql('select 1 as a, 2 as b') { select a: 1, b: 2 }
    assert_sql('select pg_sleep(1) as s, pg_sleep(2) as s2') {
      select s: pg_sleep(1), s2: pg_sleep(2)
    }
  end

  def test_select_distinct
    assert_sql('select distinct a, b') {
      select a, b, distinct: true
    }

    assert_sql('select distinct on (a + b) a, b') {
      select a, b, distinct: a + b
    }
  end
end

class FromTest < MiniTest::Test
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
    query = Q { select _l(1).as a }
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

class WithTest < MiniTest::Test
  def test_that_with_accepts_sub_queries
    assert_sql('with t1 as (select 1 as a), t2 as (select 2 as b) select * from b') {
      with t1.as { select _l(1).as a }, t2.as { select _l(2).as b }
      select all
      from b
    }
  end
end

class WhereTest < MiniTest::Test
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
      where b & !c
    }

    assert_sql('select * from a where (not (b or c))') {
      from a
      where !(b | c)
    }
  end

  def test_that_where_accepts_nil
    assert_sql('select * from a where (b is null)') {
      from a
      where b.null?
    }

    assert_sql('select * from a where (b is not null)') {
      from a
      where !b.null?
    }

    assert_sql('select * from a where (b is not null)') {
      from a
      where !b.null?
    }
  end

  def test_that_where_accepts_arithmetic_operators
    assert_sql('select * from a where ((b + c) = 42)') {
      from a
      where b + c == 42
    }
  end
end

class DSLTest < MiniTest::Test
  class Eno::Identifier
    def [](sym)
      case sym
      when Symbol
        Eno::Alias.new(JSONBExpression.new(self, sym), sym)
      else
        JSONBExpression.new(self, sym)
      end
    end
  end

  class JSONBExpression < Eno::Expression
    def to_sql(sql)
      "#{sql.quote(@members[0])}->>'#{sql.quote(@members[1])}'"
    end
  end

  def test_that_dsl_can_be_extended
    assert_sql("select attributes->>'path'") {
      select attributes[path]
    }

    assert_sql("select attributes->>'path' as path") {
      select attributes[:path]
    }
  end
end

class WindowTest < MiniTest::Test
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

class ContextTest < MiniTest::Test
  def test_that_context_passed_can_be_used_in_query
    query = Q(tbl: :nodes, field: :sample_rate, value: 42) {
      select a, b
      from tbl
      where field < value
    }
    assert_equal(
      'select a, b from nodes where (sample_rate < 42)',
      query.to_sql
    )
  end

  def test_that_context_can_be_passed_in_to_sql_method
    query = Q {
      select a, b
      from tbl
      where field < value
    }
    assert_equal(
      'select a, b from nodes where (sample_rate < 43)',
      query.to_sql(tbl: :nodes, field: :sample_rate, value: 43)
    )
  end

  def test_that_to_sql_overrides_initial_context
    query = Q(tbl: :nodes, field: :deadband) {
      select a, b
      from tbl
      where field < value
    }
    assert_equal(
      'select a, b from nodes where (sample_rate < 42)',
      query.to_sql(field: :sample_rate, value: 42)
    )

    assert_equal(
      'select a, b from nodes where (deadband < 42)',
      query.to_sql(value: 42)
    )
  end
end

class MutationTest < MiniTest::Test
  def test_that_query_can_further_refined_with_where_clause
    q = Q {
      select a, b
    }
    assert_equal('select a, b', q.to_sql)

    q2 = q.where { c < d}
    assert(q != q2)
    assert_equal('select a, b', q.to_sql)
    assert_equal('select a, b where (c < d)', q2.to_sql)

    q = Q {
      where _l(2) + _l(2) == _l(5)
    }
    assert_equal('select * where ((2 + 2) = 5)', q.to_sql)

    q2 = q.where { _l('up') == _l('down') }
    assert_equal("select * where ((2 + 2) = 5) and ('up' = 'down')", q2.to_sql)
  end

  def test_that_mutated_query_can_change_arbitrary_clauses
    q = Q { select a; from b }
    assert_equal('select a from b', q.to_sql)

    q2 = q.mutate { from c }
    assert_equal('select a from b', q.to_sql)
    assert_equal('select a from c', q2.to_sql)
  end
end

class CastTest < MiniTest::Test
  def test_that_cast_is_correctly_formatted
    assert_sql('select cast (a as b)') { select a.cast(b) }
    assert_sql('select cast (123 as float)') { select _l(123).cast(float) }
    assert_sql("select cast ('123' as integer)") { select _l('123').cast(integer) }
  end

  def test_that_cast_shorthand_is_correctly_formatted
    assert_sql('select a::b') { select a^b }
    assert_sql('select 123::float') { select _l(123)^float }
    assert_sql("select '2019-01-01 00:00+00'::timestamptz") {
      select _l('2019-01-01 00:00+00')^timestamptz
    }
  end

  def test_that_cast_works_wih_symbols
    assert_sql('select cast (a as b)') { select a.cast(:b) }
  end
end

class InTest < MiniTest::Test
  def test_that_in_is_correctly_formatted
    assert_sql('select * where a in (1, 2, 3)') { where a.in 1, 2, 3 }
    assert_sql('select * where a not in (1, 2, 3)') { where !a.in(1, 2, 3) }
  end

  def test_that_not_in_is_correcly_formatted
    assert_sql('select * where a not in (1, 2, 3)') { where a.not_in 1, 2, 3 }
  end
end

class LiteralTest < MiniTest::Test
  def test_that_numbers_are_correctly_quoted
    assert_sql('select 123') { select 123 }
    assert_sql('select 123') { select _l(123) }
    assert_sql('select (2 + 2)') { select _l(2) + _l(2) }
  end

  def test_that_strings_are_correctly_quoted
    assert_sql("select 'abc'") { select 'abc' }
  end

  def test_that_null_literal_is_correctly_quoted
    assert_sql('select null') { select null }
  end
end

class ConvenienceVariablesTest < MiniTest::Test
  def test_that_convenience_variables_do_not_change_query
    assert_sql('select unformatted_value::boolean, unformatted_value::float') {
      uv = unformatted_value
      select uv^boolean, uv^float
    }
  end
end

class ExtractEpoch < Eno::Expression
  class Eno::SQL
    def extract_epoch_from(sym)
      ExtractEpoch.new(sym)
    end
  end

  def to_sql(sql)
    "extract (epoch from #{sql.quote(@members[0])})::integer"
  end
end
