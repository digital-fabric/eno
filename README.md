# Eno is Not an ORM

[INSTALL](#installing-eno) |
[TUTORIAL](#getting-started) |
[EXAMPLES](examples)

## What is Eno?

Eno is an experimental Ruby gem for working with SQL databases. Eno provides
tools for writing SQL queries using plain Ruby and specifically for querying
PostgreSQL and SQLite databases without using an ORM library like Sequel or
ActiveRecord.

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
eno = import('eno')
```

## Composing queries

More information coming shortly...