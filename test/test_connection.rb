# frozen_string_literal: true

require_relative './helper'

require 'tempfile'
require 'etc'

class ConnectionPoolTest < Minitest::Test
  def setup
    @fn = Tempfile.new('eno_connection_pool_test').path
  end

  def test_pool_setup
    pool = Eno::ConnectionPool.new(@fn)
    assert_equal 0, pool.size
    assert_equal Etc.nprocessors, pool.max_size
  end

  def test_pool_checkout
    pool = Eno::ConnectionPool.new(@fn)
    db1 = nil
    db2 = nil
    q1 = Queue.new
    t1 = Thread.new do
      pool.checkout do |db|
        db1 = db
        q1.pop
      end
    end
    sleep 0.01
    assert_equal 1, pool.checked_out_count
    pool.checkout do |db|
      db2 = db
      assert_equal 2, pool.checked_out_count
    end
    q1 << true
    t1.join

    assert_kind_of Extralite::Database, db1
    assert_kind_of Extralite::Database, db2
    refute_equal db1, db2
    assert_equal 2, pool.size
    assert_equal 0, pool.checked_out_count
  ensure
    t1.kill
    t1.join
  end
end
