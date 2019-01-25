# frozen_string_literal: true

require_relative './ext'

class ContextTest < T
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
end

class MutationTest < T
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
      where _q(2) + _q(2) == _q(5)
    }
    assert_equal('select * where ((2 + 2) = 5)', q.to_sql)

    q2 = q.where { _q('up') == _q('down') }
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

class ConvenienceVariablesTest < T
  def test_that_convenience_variables_do_not_change_query
    assert_sql('select unformatted_value::boolean, unformatted_value::float') {
      uv = unformatted_value
      select uv^boolean, uv^float
    }
  end
end

class CustomFunctionTest < T
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
    assert_sql("select case when quality not in (1, 4, 5) then null when (datatype = 3) then case when unformatted_value::boolean then 1 else 0 end when (unformatted_value ~ '^[+-]?([0-9]*[.])?[0-9]+$') then unformatted_value::float else null end as value_float") {
      select cast_value.as value_float
    }
  end
end

class UseCasesTest < T
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