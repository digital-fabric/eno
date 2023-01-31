# frozen_string_literal: true

require_relative './helper'

class ExtensionTest < MiniTest::Test
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
end