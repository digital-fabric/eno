- Add support for parametric queries, ala Sequel:

  ```ruby
  q = Q {
    select_all
    from foo
    where bar == :$bar
  }
  q.bind(bar: 42).each 
  ```
