# frozen_string_literal: true

require 'bundler/setup'
require 'eno'
require 'minitest/autorun'

class MiniTest::Test
  def assert_sql(sql, &block)
    sql = sql.gsub("\n", ' ').strip
    q = Q(&block)
    assert_equal(sql, q.to_sql)
  end
end
