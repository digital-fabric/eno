## 0.6 2024-29

- Add support for `nil?`, `select :*`, `select foo._all`
- Add support for chained clauses
- Accept hash for where clause, add #where! method
- Add group_by clause
- Add support ranges in #in, #not_in; add support for exclusive ranges
- Allow non-integer subscript on JSON expression
- Add support for fuzzy equality operator and JSON expressions
- Add support for extensions
- Fix `or` logical operator
- Add support for custom escape proc
- Rename `#_q` to `#_l` (for literal)
- Add `#_i` method for creating identifier

# 0.5 2019-01-25

- Implement query combination: `union`, `intersect`, `except`
- Implement `#not_in` method
- Implement case expression (using `#cond`)
- Implement not in expression
- Implement in operator
- Implement cast operator (using either `#cast` or `#^`)

# 0.4 2019-01-21

- Implement query mutation
- Can now use `!` as `not` operator
- Clauses as real expressions
- Implement context injection
- Refactor and simplify code

# 0.1 2019-01-16

- First working version
