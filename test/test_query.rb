# frozen_string_literal: true

require_relative './helper'

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

  def test_that_context_is_accessible_for_sub_query
    q1 = Q { select a }
    q2 = Q { select b; from q1.as t1 }
    assert_equal('select 3 from (select 2) t1', q2.to_sql(a: 2, b: 3))
    assert_equal('select 3 from (select 2) tbl', q2.to_sql(a: 2, b: 3, t1: :tbl))
  end

  def test_that_to_sql_context_overrides_initialized_context
    q1 = Q(t1: :tbl1) { select a from t1 }
    q2 = Q(t2: :tbl2) { select b; from q1.as t2 }
    assert_equal('select 3 from (select 2 from tbl1) tbl2', q2.to_sql(a: 2, b: 3))
  end

  def test_that_context_method_gives_context
    q = Q { from users; where name == context[:user_name] }
    assert_equal("select * from users where (name = 'foo')", q.to_sql(user_name: 'foo'))
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

class ConvenienceVariablesTest < MiniTest::Test
  def test_that_convenience_variables_do_not_change_query
    assert_sql('select unformatted_value::boolean, unformatted_value::float') {
      uv = unformatted_value
      select uv^boolean, uv^float
    }
  end

  def test_convenience_variable_reuse
    assert_sql(<<~SQL
      select json_extract(record, '$.stamp'), json_extract(record, '$.path') from log
      where ((json_extract(record, '$.project') = 'nogarus')
      and (json_extract(record, '$.stamp') between t1 and t2))
      order by json_extract(record, '$.stamp') desc
    SQL
    ) {
      rec = json(record)
      stamp = rec.stamp
    
      select stamp, rec.path
      from log
      where (rec.project == 'nogarus') & (stamp.in t1..t2)
      order_by stamp.desc
    }
  end
end

class CustomFunctionTest < MiniTest::Test
  class Eno::SQL
    FLOAT_RE = '^[+-]?([0-9]*[.])?[0-9]+$'.freeze
    
    def cast_value
      uv = unformatted_value
      cond(
        quality.not_in(1, 4, 5) => null,
        (datatype == 3) => cond(uv^boolean => 1, default => 0),
        (uv =~ FLOAT_RE) => uv^float,
        default => null
      )
    end
  end

  def test_that_custom_function_can_be_used_normally
    assert_sql("select case when (quality not in (1, 4, 5)) then null when (datatype = 3) then case when unformatted_value::boolean then 1 else 0 end when (unformatted_value like '^[+-]?([0-9]*[.])?[0-9]+$') then unformatted_value::float else null end as value_float") {
      select cast_value.as value_float
    }
  end
end

class CombinationTest < MiniTest::Test
  def test_union
    query = Q { select a }.union { select b}
    assert_equal("(select a) union (select b)", query.to_sql)

    q1 = Q { select a }
    q2 = Q { select b }
    assert_equal("(select a) union (select b)", q1.union(q2).to_sql)

    q3 = q1.union(q2).union { select c }
    assert_equal("((select a) union (select b)) union (select c)", q3.to_sql)

    q4 = q1.union(Q { select b}, Q { select c })
    assert_equal("(select a) union (select b) union (select c)", q4.to_sql)

    assert_sql("(select a) union (select b)") {
      union q1, q2
    }
  end

  def test_union_all
    q1 = Q { select a }.union(all: true) { select b }
    assert_equal("(select a) union all (select b)", q1.to_sql)

    q2 = Q { select a }.union_all(Q { select b}, Q { select c })
    assert_equal("(select a) union all (select b) union all (select c)", q2.to_sql)
  end

  def test_union_shorthand
    q1 = Q { select a }
    q2 = Q { select b }
    q3 = Q { select c }
    assert_equal(
      '((select a) union (select b)) union (select c)',
      (q1 | q2 | q3).to_sql
    )
  end

  def test_intersect
    query = Q { select a }.intersect { select b}
    assert_equal("(select a) intersect (select b)", query.to_sql)

    q1 = Q { select a }
    q2 = Q { select b }
    assert_equal("(select a) intersect (select b)", q1.intersect(q2).to_sql)

    q3 = q1.intersect(q2).intersect { select c }
    assert_equal("((select a) intersect (select b)) intersect (select c)", q3.to_sql)

    q4 = q1.intersect(Q { select b}, Q { select c })
    assert_equal("(select a) intersect (select b) intersect (select c)", q4.to_sql)

    assert_sql("(select a) intersect (select b)") {
      intersect q1, q2
    }
  end

  def test_intersect_all
    q1 = Q { select a }.intersect(all: true) { select b }
    assert_equal("(select a) intersect all (select b)", q1.to_sql)

    q2 = Q { select a }.intersect_all(Q { select b}, Q { select c })
    assert_equal("(select a) intersect all (select b) intersect all (select c)", q2.to_sql)
  end

  def test_intersect_shorthand
    q1 = Q { select a }
    q2 = Q { select b }
    q3 = Q { select c }
    assert_equal(
      '((select a) intersect (select b)) intersect (select c)',
      (q1 & q2 & q3).to_sql
    )
  end

  def test_except
    query = Q { select a }.except { select b}
    assert_equal("(select a) except (select b)", query.to_sql)

    q1 = Q { select a }
    q2 = Q { select b }
    assert_equal("(select a) except (select b)", q1.except(q2).to_sql)

    q3 = q1.except(q2).except { select c }
    assert_equal("((select a) except (select b)) except (select c)", q3.to_sql)

    q4 = q1.except(Q { select b}, Q { select c })
    assert_equal("(select a) except (select b) except (select c)", q4.to_sql)

    assert_sql("(select a) except (select b)") {
      except q1, q2
    }
  end

  def test_except_all
    q1 = Q { select a }.except(all: true) { select b }
    assert_equal("(select a) except all (select b)", q1.to_sql)

    q2 = Q { select a }.except_all(Q { select b}, Q { select c })
    assert_equal("(select a) except all (select b) except all (select c)", q2.to_sql)
  end

  def test_except_shorthand
    q1 = Q { select a }
    q2 = Q { select b }
    q3 = Q { select c }
    assert_equal(
      '((select a) except (select b)) except (select c)',
      (q1 ^ q2 ^ q3).to_sql
    )
  end

  def test_combination
    q1 = Q { select a }
    q2 = Q { select b }
    q3 = Q { select c }
    assert_equal(
      '((select a) union (select b)) intersect (select c)',
      ((q1 | q2) & q3).to_sql
    )

    assert_equal(
      '((select 1) union (select 2)) intersect (select 1)',
      ((q1 | q2) & q3).to_sql(a: 1, b: 2, c: 1)
    )
  end
end

class UseCasesTest < MiniTest::Test
  class Eno::SQL
    def extract_epoch_from(sym)
      ExtractEpoch.new(sym)
    end
  end

  class ExtractEpoch < Eno::Expression
    def to_sql(sql)
      "extract (epoch from #{sql.quote(@members[0])})::integer"
    end
  end
  
  def test_1
    assert_sql("select extract (epoch from stamp)::integer as stamp, quality, value, unformatted_value, datatype from states where ((path = '/r1') and (stamp >= '2019-01-01 00:00:00+00') and (stamp < '2019-01-02 00:00:00+00')) order by stamp desc limit 1") {
      select extract_epoch_from(stamp).as(stamp), quality, value, unformatted_value, datatype
      from states
      where (path == '/r1') & (stamp >= '2019-01-01 00:00:00+00') & (stamp < '2019-01-02 00:00:00+00')
      order_by stamp.desc
      limit 1
    }
  end

  def test_2
    # http://www.postgresqltutorial.com/postgresql-window-function/
    assert_sql('select product_name, price, group_name, avg(price) over (partition by group_name) from products inner join product_groups using (group_id)') {
      select  product_name, 
              price,
              group_name,
              avg(price).over { partition_by group_name }
      from products.inner_join(product_groups, using: group_id)
    }
  end

  def test_3
    # http://www.postgresqltutorial.com/postgresql-window-function/
    assert_sql('select product_name, group_name, price, row_number() over (partition by group_name order by price) from products inner join product_groups using (group_id)') {
      select  product_name,
              group_name,
              price,
              row_number(_).over { 
                partition_by group_name
                order_by price
              }
      from products.inner_join(product_groups, using: group_id)
    }
  end

  def test_4
    # http://www.postgresqltutorial.com/postgresql-window-function/
    assert_sql('select product_name, group_name, price, lag(price, 1) over (partition by group_name order by price) as prev_price, (price - lag(price, 1) over (partition by group_name order by price)) as cur_prev_diff from products inner join product_groups using (group_id)') {
      select  product_name,
              group_name,
              price,
              lag(price, 1).over {
                partition_by group_name
                order_by price
              }.as(prev_price),
              (price - lag(price, 1).over {
                partition_by group_name
                order_by price
              }).as(cur_prev_diff)
      from products.inner_join product_groups, using: group_id
     }
  end
end
