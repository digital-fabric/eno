# Eno is Not an ORM

[INSTALL](#installing-eno) |
[TUTORIAL](#getting-started) |
[EXAMPLES](examples)

## What is Eno?

Eno is an experimental Ruby gem for working with SQL databases. Eno provides
tools for writing SQL queries using plain Ruby and specifically for querying
PostgreSQL and SQLite databases.

Eno provides the following features:

- Compose `SELECT` statements using plain Ruby syntax
- Create arbitrarily complex `WHERE` clauses
- Support for common table expressions (CTE) and joins
- Compose queries and sub-queries
- Create parametric queries using context variables
- Reusable queries can be further refined and mutated

## What is it good for?

So why would anyone want to compose queries in Ruby instead of in plain SQL?
That's actually a very good question. Libraries like ActiveRecord and Sequel
already provide tools for querying relational databases. There's usage patterns
like ActiveRecord's `where`:

```ruby
Client.where(order_count: [1, 3, 5])
```

And Sequel is (quite) a bit more flexible:

```ruby
Client.where { order_count > 10 }
```

But both stumble when it comes to putting together more complex queries.
ActiveRecord queries in particular aren't really composable, making it actually
easier to filter and manipulate records inside your app code than in your
database.

With both ActiveRecord and Sequel you'll need to eventually provide snippets of
literal SQL. This is time-consuming, prevents your queries from being composable
and makes it easy to expose your app to SQL injection.

## Installing eno

Using bundler:

```ruby
gem 'eno'
```

Or manually:

```bash
$ gem install eno
```

## Getting started

To use eno in your code just require it:

```ruby
require 'eno'
```

Alternatively, you can import it using [Modulation](https://github.com/digital-fabric/modulation):

```ruby
Eno = import('eno')
```

## Putting together queries

Eno makes it easy to compose SQL queries using plain Ruby syntax. It takes care
of formatting table and column identifiers and literals, and allows you to
compose multiple queries into a single `SELECT` statement.

To compose a query use the `Kernel#Q` method, providing a block in which the
query is built:

```ruby
Q {
  select a, b
  from c
}
```

To turn the query into SQL, use the `#to_sql` method:

```ruby
Q {
  select a, b
  from c
}.to_sql #=> "select a, b from c"
```

## Expressions

Eno lets you build arbitrarily complex expressions once inside the query block.
You can freely mix identifiers and literals, use most operators (with certain
caveats) and make function calls.

### Identifiers

An identifier is referenced simply using its name:

```ruby
Q {
  select foo
} #=> select foo
```

Identifiers can be qualified by using dot-notation:

```ruby
Q {
  select foo.bar
} #=> select foo.bar
```

### Literals

Literals can be specified as literals

```ruby
Q {
  select x * 10
} #=> select x * 10
```

However, if the first argument of an expression is a literal, it will need to be
wrapped in a call to `#_q`:

```ruby
Q {
  select _q(2) + 2
} #=> select 2 + 2
```

### Operators

Eno supports the following mathematical operators:

operator | description
---------|------------
`+`      | addition
`-`      | subtraction
`*`      | multiplication
`/`      | division
`%`      | modulo (remainder)

Logical operators are supported using the following operators:

operator | description
---------|------------
`&`      | logical and
`\|`      | logical or       
`!`      | logical not

The following comparison operators are supported:

operator | description
---------|------------
`==`     | equal
`!=`     | not equal
`<`      | less than
`>`      | greater than
`<=`     | less than or equal
`>=`     | greater than or equal      

An example involving multiple operators:

```ruby
Q {
  select (a + b) & (c * d), e >= f
} #=> select (a + b) and (c * d), e >= f
```

### functions

You can also use SQL functions:

```ruby
Q {
  select user_id, max(score)
  from exams
  group_by user_id
}
```

## SQL clauses

Eno supports the following clauses:

### Select

The `#select` method is used to specify the list of selected expressions for a
`select` statement. The `select` method accepts a list of expressions:

```ruby
Q { select a, b + c, d.as(e) } #=> select a, b + c, d as e
```

The `#select` method can also accept a hash mapping aliases to expressions:

```ruby
Q { select c: a + b, f: d(e) } #=> select a + b as c, d(e) as f
```

Columns can be qualified using dot-notation:

```ruby
Q { select a.b, c.d.e } #=> select a.b, c.d.e
```

Note: if `#select` is not called within a query block, a `select *` is assumed:

```ruby
Q { from mytable } #=> select * from mytable
```

### From

The `#from` method is used to specify one or more sources for the query. Usually
this would be a table name, a subquery, a CTE name (specified using `#with`):

```ruby
Q { from a, b, c } #=> select * from a, b, c
Q { from a.as b } #=> select * from a as b
```

Subqueries can also be used in `#from`:

```ruby
Q {
  select sum(foo.score)
  from Q { select * from scores }.as(foo)
} #=> select sum(foo.score) from (select score from scores) as foo
```

### Where

The `#where` method is used to specify a record filter:

```ruby
Q {
  from users
  where name == 'John Doe' & age > 30
} #=> select * from users where (name = 'John Doe') and (age > 30)
```

Where clauses can be of arbitrary complexity (as shown [above](#expressions)),
and can also be chained in order to mutate and further filter query:

```ruby
query = Q {
  from users
  where state == 'CA'
}
query.where { age >= 25 } #=> select * from users where (state = 'CA') and (age >= 25)
```



## Hooking up Eno to your database

In and of itself, Eno is just an engine for building SQL queries. To actually
run your queries, you'll need to hook Eno to your database. Here's an example
of how to open a connection to a PostgreSQL database and then easily issue
queries to it:

```ruby
require 'pg'

DB = PG.connect(host: '/tmp', dbname: 'myapp', user: 'myuser')
def DB.q(**ctx, &block)
  query(**ctx, &block).to_a
end

# issue a query
DB.q {
  from users
  select 
}
```

Another way to issue queries is by defining methods on Eno::Query:

```ruby
def Eno::Query.each(**ctx, &block)
  DB.query(to_sql(**ctx)).each(&block)
end
```

## Roadmap

Eno is intended as a complete solution for eventually expressing *any* SQL query
in Ruby (including `INSERT`, `UPDATE` and `DELETE` and `ALTER TABLE`
statements).

In the future, Eno could be used to manipulate queries in other ways:

- `EXPLAIN` your queries.
- Introspect different parts of a query (for example look at results of
  subqueries or CTE's).
- Transform CTE's into subqueries (for example to overcome optimization
  boundaries).
- Create views from queries.
- Compose data manipulation statements using `SELECT` subqueries.
