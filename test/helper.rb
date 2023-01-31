# frozen_string_literal: true

require 'bundler/setup'
require 'eno'
require 'minitest/autorun'

T = MiniTest::Test
class T
  def assert_sql(sql, &block); assert_equal(sql, Q(&block).to_sql); end
end
