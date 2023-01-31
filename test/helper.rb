# frozen_string_literal: true

require 'bundler/setup'
require 'eno'
require 'minitest/autorun'

class MiniTest::Test
  def assert_sql(sql, &block); assert_equal(sql, Q(&block).to_sql); end
end
