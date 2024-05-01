# Eno - the SQLite Toolkit for Ruby

<h2 style="align: center">Eno's Not an ORM</h2>

[INSTALL](#installing-eno) |
[TUTORIAL](#getting-started) |
[EXAMPLES](examples)

## What is Eno?

Eno is a Ruby gem for working with SQLite databases in Ruby. Eno provides a set
of tools for implementing various persistence and data access patterns using the
SQLite embedded database engine.

Features:

- Out of the box support for concurrent database access.
- Automatic connection pooling, with support for thread- and fiber-based
  concurrency.
- Data stores with specialized APIs for different data access patterns.
- DSL for expressing SQL queries with support for CTEs and window functions.
- Based on [Extralite].

## Synopsis

```ruby
Eno.connect '/path/to/my.db'

# define a query
q = Q {
  select :*
  from foo
}
# or alternatively
q = Eno.q { select_all; from foo }

# query mutation
Q.from(:foo).select_all

# get all rows
q.to_a

# iterate through records
q.each { |r| ... }

# mutate query
q.where { bar == 42 }.to_a

# count records
q.where { bar == 42 }.count
# which is short for:
q.where { bar == 42 }.select { count(:*) }.single_value

# parametrized queries
q = Q {
  select_all
  from foo
  where bar == _(bar)
}

q.to_a(bar: 42)

class Post < Eno::ModelStore
  schema(:post) do
    column id:      integer, :primary_ke
    column user_id: integer
    column title:   text
    column body:    text

    foreign_key user_id: [:users, :id]
  end
end

class User < Eno::ModelStore
  schema(:user) do
    column id:    integer, :primary_key
    column name:  text
  end

  one_to_many :posts do
    left join post
    on post.user_id == user.id
    order_by post.id
  end

  def posts
    this = self
    Post.where { user_id.in this.select { id } }
  end
end

h = User.insert(name: 'foo')
h.class #=> Hash
h[:id] #=> 1
h[:name] #=> 'foo'

u = User[1]
u #=> User <where id = 1>
name = u.values[:name]

u.update(name: 'bar')

posts = u.posts
posts.class #=> Post

posts.each do |r|
  puts r.title
  puts r.body
end

# checkout a connection explicitly and wrap in a transaction:
Eno.transaction do
  Posts.where { user_id == 3 }.update(user_id: nil)
  User[3].delete
end

# protection against updating/deleting without a where clause
User.delete
#=> Eno::Error 'To delete all records use the #all modifier, e.g. foo.all.delete'
User.all.delete #=> 1

# custom modifiers
class Post < Eno::ModelStore
  ...

  def by_category(category)
    where(category:)
  end

  def published
    where(published: true)
  end
end

foo_posts = Post.published.by_category('foo')

foo_posts.where_clause
#=> "where (published is true) and (category = 'foo')"

# Key-value store
cache = Eno::KVStore.new('cache')
cache.set('foo', 'bar')

# set TTL of 30 seconds
cache.setex('foo', 30, 'baz')

# periodic cache eviction
bouncer = Thread.new do
  loop do
    sleep 10
    cache.evict_expired_keys
  end
end
```
