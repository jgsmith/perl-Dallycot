---
title: Language Overview
breadcrumbs:
  - url: /guides/
    title: Guides
---

Dallycot is a linked data language designed to be useful for exploring a broad
range of linked data types, from traditional RDF to XML-based documents using
linked data approaches.

## Reference

### List and Expression Manipulation

`[...]` ([Stream](./types#stream))
`<...>` ([Vector](./types#vector))
[...](./collections)

### Associations and Graphs

`{...}` ([Graph](./types#graph))
[...](./graphs)

### Functional Operations

`@` ([map](./functional#map))
`%` ([filter](./functional#filter))
[`foldl`](/ns/streams/1.0#foldl)
[...](./functional)

### Pattern Matching

### Rules and Transformations

### Definitions and Assignments

`:=` ([assign](./definition#assign))
[...](./definition)

### Logic and Tests

`=` ([equal](./logic-and-tests#equal))
`<>` ([not equal](./logic-and-tests#not-equal))
[`and`](./logic-and-tests#and)
[`or`](./logic-and-tests#or)
[`member?`](./streams/1.0#member?)
[...](./logic-and-tests)

### Scoping and Modularity

`(...)` ([scope](./scoping#parens))
[...](./scoping)

### Procedural Programming

[`;`](./controls#semi)
`(...)` ([case](./controls#cases))
[...](./controls)

### String Manipulation

`"..."` ([String](./types#string))
[...](./string-manipulation)
