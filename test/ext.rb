# frozen_string_literal: true

require 'modulation'
require 'minitest/autorun'

Eno = import '../lib/eno'

T = MiniTest::Test
class T
  def assert_sql(sql, &block); assert_equal(sql, Q(&block).to_sql); end
end
