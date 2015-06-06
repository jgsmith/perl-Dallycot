---
title: Language Overview
breadcrumbs:
  - url: /guides/
    title: Guides
---

Dallycot is a linked data language designed to be useful for exploring a broad
range of linked data types, from traditional RDF to XML-based documents using
linked data approaches.

## Basic Syntax

### Block

A **block** is a sequence of expressions. The value of the block is the value of the last expression in the sequence. Expressions in a block are separated by semicolons (`;`).

Blocks introduce a new child scope. Any assignments made in a block are only available in that block or enclosed blocks; never in the parent block.

```
(
  a := 2;
  b := 3;
  (
    a := 3
  );
  (
    a + b = 6
  )
)
```

This block evaluates to `false` because `2 + 4` does not equal `6`. The value of `a` is `2` when evaluated at the end because the assignment of `3` to `a` is in a child scope.

### Assignment

The **assignment** operator (`:=`) places the value of the expression to the right of the operator into a bucket identified by the name to the left of the operator. Within a scope, a bucket may be filled only once.

```
a := 3
```

Places the value `3` in the bucket labeled `a`.

```
foo := "A string";
bar := "Another string";
foo := "A different string";
```

Raises an error when `foo` is filled the second time.

The order in which you make assignments is not significant. Assignments may reference each other regardless of their order in the code. The only caveat is that circular references will deadlock. For example:

```
a := b * 3;
b := a - 3;
```

This will compile just fine, but the system will wait on `b` to complete `a`, and wait on `a` to complete `b`.

### Function Definition

The **function definition** operator (`:>`) associates an expression to the right of the operator with a signature to the left of the operator. If the signature is prefixed with an identifier, then the resulting anonymous function is assigned to that identifier using the assignment mechanism.

In fact, the following two expressions are equivalent.

```
f(x) :> x * 2;
f := (x) :> x * 2;
```

Both create a function that takes a single argument (`x`) and returns the argument doubled. This function is assigned to the bucket labeled `f`. As with the assignment operator, this code snippet would raise an error because `f` is assigned twice.

Function definitions are just fancy assignments, so function definitions are run at the same time as assignments: before any expressions that aren't assignments and after any namespace prefix or usage declarations.

#### Optional Arguments

Function signatures may have optional arguments by giving default values. All optional arguments must come at the end of the signature.

```
f(x, y = 2)  :> x * y;
6 = f(3);
9 = f(3,3)
```

#### Options

Function signatures may also have options: named arguments with default values. These come after any optional arguments.

```
f(x, multiplier -> 2) :> x * multiplier;
6 = f(3);
9 = f(3, multiplier -> 3)
```

### Function Application

The function application operator (`(...)`) binds the expressions within the parentheses to the argument list of function from the expression preceeding the parentheses and then applies the definition of the function to that binding.

```
f(1, 3)
```

Binds the expressions `1` and `3` to the function stored in the bucket labeled `f` and then applies the definition of `f` to that pair of expressions.

## Data Types

### Scalars

#### Boolean

The two Boolean values `true` and `false` are the only members of this type.

#### Numeric

Dallycot uses arbitrary length rational numbers to represent numeric quantities. These numbers are translated into arbitrary precision floating point numbers as necessary for internal calculations (e.g., the trigonometric functions).

Dallycot can also represent positive and negative inifities as well as results that are not a number (NaN). NaN is distinct from Undefined.

#### Undefined

#### URI




### Collections

#### Stream

A stream is a linked list of values. Dallycot uses a stream to represent the RDF concept of List.

A stream is a list of expressions within square brackets. If the last expression is not a literal value, it is converted into an anonymous function and considered a generator for the rest of the stream.

#### String

A string is a vector of characters with a language label. Note that there is no scalar character type. A character is a string with length one.

A string is a list of characters within double quotes and an optional language label.

#### Vector

A vector is a finite sequence of values.

A vector is a list of expressions within angle brackets.

## Control Structures

Dallycot doesn't have loop constructs or typical control structures. Looping is accomplished with tail recursion and flow control is done through a general purpose case construct.

### "if" ... "then" ... "else" and "given" ... "when"

Dallycot uses the same structure for both the simple `if` and `given` (or `switch`) statements: a list of tests and expressions. The result is the value of the first expression for which its paired test yields true. If no test yields true, then any default expression is used.

For example, the C expression `x % 2 == 0 ? "even" : "odd"` is written as:

```
(
  ( x mod 2 = 0 ) : 'even'
  (             ) : 'odd'
)
```

A "switch" statement is the same as a sequence of "if" statements with an implied topic. In Dallycot, this is the same as above except with more tests and expressions.

### "for" Loop

Looping is executing the same code again with different parameters. In a purely functional language, this is no different than executing the body with the last value of the loop variable. The easiest way to accomplish this in Dallycot is to walk along a sequence representing the loop variable and execute some function for each position in the sequence. This is done using the map (`@`) operator.

```
last( f @ 1..20 )
```

### "while" loop

A "while" loop is similar to a "for" loop, but rather than having a predetermined number of executions, the body is executed while (or until) some condition is met. The easiest way to accomplish this in Dallycot is to use tail-recursion (using the [`y-combinator`](/ns/loc/1.0/#y-combinator) function) until or while the condition holds.

```
while(full-sequence, condition, body) :> last(
  y-combinator(
    (self, sequence) :> (
      result := body(sequence');
      (
        ( condition(result) ) : [ result, self(self, sequence...) ]
        (                   ) : ( )
      )
    )
  )(full-sequence)
);
```

This can be used, for example, to find the largest prime less than 1,000:

```
while(1.., { # < 1000 }, prime);
```
