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

And Sequel is a bit more flexible:

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

## Using expressions

Once inside the query block, you can build arbitrarily complex expressions. You
can mix logical and arithmetic operators:

```ruby
Q { select (a + b) & (c * d) }.to_sql #=> select (a + b) and (c * d)
```

You can also use SQL functions:

```ruby
Q {
  select user_id, max(score)
  from exams
  group_by user_id
}
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
