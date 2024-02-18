# frozen_string_literal: true

require_relative './helper'

class ExtensionTest < Minitest::Test
  module FooExtension
    def foo(x)
      Q {
        from foo
        where bar == x
      }
    end
  end

  def test_extend
    query = Q {
      extend FooExtension

      select sum(col)
      from foo(42)
    }
    assert_equal(
      'select sum(col) from (select * from foo where (bar = 42)) t1',
      query.to_sql
    )
  end

  module TwizzExtension
    def twizz
      [1, 2, 3]
    end
  end

  def test_eno_extension
    Eno.extension(TwizzExtension)

    query = Q {
      from tbl
      where foo == twizz
    }
    assert_equal(
      'select * from tbl where (foo = [1, 2, 3])',
      query.to_sql
    )
  end
end
