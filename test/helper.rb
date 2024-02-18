# frozen_string_literal: true

require 'bundler/setup'
require 'eno'
require 'minitest/autorun'

class Minitest::Test
  def assert_sql(sql, &block)
    sql = sql.gsub("\n", ' ').gsub(/\s{2,}/, ' ').gsub('( ', '(').gsub(' )', ')').strip
    q = Q(&block)
    assert_equal(sql, q.to_sql)
  end
end
