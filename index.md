---
title: Welcome to Dallycot
layout: default
---

Dallycot is designed to work with the asynchronous nature of the web. When running a program in Dallycot, the web is your memory, providing data and code storage.

*N.B.*: Almost everything about Dallycot is subject to change. For now, Dallycot provides read-only access to information.

Linked code solves one of the outstanding problems in digital Humanities: recording the computational provenance of derived information. Linked code allows reasoning about how different data sets might be related via computational paths. With a proper engine, linked code is even executable.

## Writing Dallycot

Dallycot provides a custom functional language designed to think the way linked data thinks. See [the W3C Linked Data Platform specification](http://www.w3.org/TR/ldp/) for an example of the kind of data services Dallycot will target.

Dallycot is not a query language. Projects like [Marmotta](http://marmotta.apache.org/) provide linked data query languages.

### Example: Euclid's algorithm for GCD

This uses simple recursion to calculate the greatest common divisor.

```
gcd(a, b) :> (
  (a = 0) : b
  (b = 0) : a
  (a > b) : gcd(a mod b, b)
  (     ) : gcd(a, b mod a)
)
```

## When Not to Use Dallycot

Because anything might result in retrieving information from the web, Dallycot makes extensive use of promises. Promises are great for managing asynchronous execution, but introduce overhead that makes programs slower if all of the information is local to the processor.

Dallycot is not designed to be good at:

- Immediate gratification

  Some programs take a while. When coupled with ad hoc information retrieval over the web, programs can seem to slow to a crawl. This is the nature of linked data in general, not Dallycot. If you already know exactly which data you will need, and how the data fits together, then consider processing it locally with a SPARQL service or a general purpose programming language designed to work exclusively with local data.

- Scientific computing

  Use programs such as Matlab, Mathematica, or R. Consider the scientific computing libraries available to Perl, Python, or Ruby.
