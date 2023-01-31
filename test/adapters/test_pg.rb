# frozen_string_literal: true

require_relative '../ext'
import('../../lib/eno/pg')

require 'pp'

class PostgresTest < MiniTest::Test
  DB = PG.connect(
    host:     '/tmp',
    user:     'reality',
    password: nil,
    dbname:   'reality',
    sslmode:  'require'
  )

  def test_correct_escaping
    results = DB.q {
      select _l("abc def 'ghi'\n").as(:"jkl mno")
    }.to_a
    assert_equal(1, results.size)
    assert_equal(['jkl mno'], results.first.keys)
    assert_equal(["abc def 'ghi'\n"], results.first.values)
  end

  def test_identifier_escaping
    query = Q {
      select _i("abc'def\"ghi")
    }
    assert_equal("select \"abc'def\"\"ghi\"", DB.query_to_sql(query))
  end
end
