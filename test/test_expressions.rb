# frozen_string_literal: true

require_relative './ext'

class ExpressionTest < T
  def test_aliases
    assert_sql('select 1 as c') { select _l(1).as c }
    assert_sql('select a as b') { select a.as b }
    assert_sql('select a as b, c as d') { select (a.as b), (c.as d) }
  end

  def test_aliased_function_expressions
    assert_sql('select pg_sleep(1) as s, pg_sleep(2) as s2') {
      select pg_sleep(1).as(s), pg_sleep(2).as(s2)
    }
  end

  def test_that_aliases_can_be_expressed_with_symbols
    assert_sql('select pg_sleep(1) as s, pg_sleep(2) as s2') {
      select pg_sleep(1).as(:s), pg_sleep(2).as(:s2)
    }
  end

  def test_qualified_names
    assert_sql('select a.b, c.d as e') {
      select a.b, c.d.as(e)
    }

    assert_sql('select a.b.c.d') {
      select a.b.c.d
    }
  end
end

class OpTest < T
  def test_comparison_operators
    assert_sql('select (a = b)') { select a == b }
    assert_sql('select (a = b)') { select !(a != b) }
    assert_sql('select (a = (b + c))') { select a == (b + c) }

    assert_sql('select (a <> b)') { select (a != b) }
    assert_sql('select (a <> b)') { select !(a == b) }

    assert_sql('select (a > b), (c < d)') { select (a > b), (c < d) }
    assert_sql('select (a >= b), (c <= d)') { select !(a < b), !(c > d) }

    assert_sql('select (a >= b), (c <= d)') { select (a >= b), (c <= d) }
    assert_sql('select (a > b), (c < d)') { select !(a <= b), !(c >= d) }
  end

  def test_math_operators
    assert_sql('select (a + b), (c - d)') { select a + b, c - d }
    assert_sql('select (a * b), (c / d), (e % f)') { select a * b, c / d, e % f }

    assert_sql('select (a + (b * c))') { select a + b * c }
  end

  def test_logical_operators
    assert_sql('select (a and b), (c or d)') { select a & b, c | d }
    assert_sql('select (a and (not b))') { select a & !b }
    assert_sql('select (not (a or b))') { select !(a | b) }
  end

  def test_cast_shorthand_operator
    assert_sql('select a::integer') { select a^integer }
  end
end

class CastTest < T
  def test_that_cast_is_correctly_formatted
    assert_sql('select cast (a as b)') { select a.cast(b) }
    assert_sql('select cast (123 as float)') { select _l(123).cast(float) }
    assert_sql("select cast ('123' as integer)") { select _l('123').cast(integer) }
  end

  def test_that_cast_shorthand_is_correctly_formatted
    assert_sql('select a::b') { select a^b }
    assert_sql('select 123::float') { select _l(123)^float }
    assert_sql("select '2019-01-01 00:00+00'::timestamptz") {
      select _l('2019-01-01 00:00+00')^timestamptz
    }
  end

  def test_that_cast_works_wih_symbols
    assert_sql('select cast (a as b)') { select a.cast(:b) }
  end
end

class InTest < T
  def test_that_in_is_correctly_formatted
    assert_sql('select * where a in (1, 2, 3)') { where a.in 1, 2, 3 }
    assert_sql('select * where a not in (1, 2, 3)') { where !a.in(1, 2, 3) }
  end

  def test_that_not_in_is_correcly_formatted
    assert_sql('select * where a not in (1, 2, 3)') { where a.not_in 1, 2, 3 }
  end
end

class LiteralTest < T
  def test_that_numbers_are_correctly_quoted
    assert_sql('select 123') { select 123 }
    assert_sql('select 123') { select _l(123) }
    assert_sql('select (2 + 2)') { select _l(2) + _l(2) }
  end

  def test_that_strings_are_correctly_quoted
    assert_sql("select 'abc'") { select 'abc' }
  end

  def test_that_null_literal_is_correctly_quoted
    assert_sql('select null') { select null }
  end
end

class ConditionalTest < T
  def test_that_cond_expression_is_correctly_formatted
    assert_sql('select case when (a < b) then c else d end') {
      select cond(
        (a < b) => c,
        default => d
      )
    }
  end

  def test_that_cond_expression_can_be_nested
    assert_sql("select case when quality not in (1, 4, 5) then null when (datatype = 3) then case when unformatted_value::boolean then 1 else 0 end when (unformatted_value ~ '^[+-]?([0-9]*[.])?[0-9]+$') then unformatted_value::float else null end as value_float") {
      select cond(
        !quality.in(1, 4, 5) => null,
        datatype == 3 => cond(
          unformatted_value^boolean => 1,
          default => 0
        ),
        unformatted_value =~ '^[+-]?([0-9]*[.])?[0-9]+$' => unformatted_value^float,
        default => null
      ).as value_float
    }
  end
end

class AliasTest < T
  def test_that_alias_is_escaped_as_identifier
  end
end