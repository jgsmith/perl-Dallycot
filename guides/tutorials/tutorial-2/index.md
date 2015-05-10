---
title: "Tutorial 2: Labels and Types"
breadcrumbs:
  - url: /guides/
    title: Guides
  - url: /guides/tutorials/
    title: Tutorials
---

You can associate information with a temporary label for reference later. These labeled buckets can hold anything, so there's no need to define different buckets for different types of information. Labels can be associated once within a scope, and order doesn't matter as long as there aren't any circular references (e.g., label `a` depending on label `b`, and label `b` depending on label `a`).

## Using Labels

You can associate a value with a label using the assignment operator (`:=`). For example,

```
x := 3;
y := 4;
```

assigns the value `3` to the label `x` and the value `4` to the label `y`.

You can use these labels in expressions. For example, `x + y` adds together the values labeled `x` and `y`, resulting in the value `7`.

A more advanced example uses lists. For example, you could use `apples` and `oranges` to reference lists of the types of each fruit:

```
apples := [ "fuji", "macintosh", "granny smith" ];
oranges := [ "naval", "blood", "mandarin" ];
```

We can use these lists in other expressions just by using the name `apples` or `oranges`. In this case, we're using the zip operator (`Z`) to zip together two lists. This creates a new list by pairing up corresponding items from each list.

```
apple-counts := [ 1, 3, 5 ] Z apples;
orange-counts := [ 3, 1, 2 ] Z oranges;
```

We've produced two new pieces of information: a list for apples and oranges associating a number with each type of fruit. Perhaps it's our inventory. We could get the same results with the following:

```
apple-counts := [
    [ 1, "fuji" ],
    [ 3, "macintosh" ],
    [ 5, "granny smith" ]
];

orange-counts := [
    [ 3, "naval" ],
    [ 1, "blood" ],
    [ 2, "mandarin" ]
];
```



## Types

Buckets don't have types. The information in the bucket does. This distinction is important because in statically typed languages, buckets also have types. For example, if you declare something in C to hold integers, then it can only hold integers. In languages like Ruby, a bucket can hold anything, but each thing in the bucket has a definite type.

For now, Dallycot has a limited list of information types it knows about:

<dl>
<dt>Boolean</dt><dd>The type with two members: <code>true</code> and <code>false</code>.</dd>
<dt>Numeric</dt><dd>This includes integers and rationals. Because all numbers on a computer are finite precision, all numbers can be represented as rationals. Certain math routines, such as the trigonometric functions, use floating representations for intermediate calculations, but results are converted to rationals representing the required precision.</dd>
<dt>Set</dt><dd>An array of unique values. Sets always have finite size. Values in a set are not ordered.</dd>
<dt>Stream</dt><dd>A basic linked list. Streams can have generators. When a stream terminates with a generator, its size is considered infinite.</dd>
<dt>String</dt><dd>A string is a sequence of characters. Strings respond to the head and tail operators.</dd>
<dt>URI</dt><dd>A pointer to a resource on the web.</dd>
<dt>Vector</dt><dd>An array of values. Vectors always have finite size. Values in a vector are ordered by their position in the vector.</dd>
</dl>

We'll cover some of these in more detail as we go through the tutorials.

## Exercise: Simple input/output program

Write a short program that prompts for the name of the person running the program and then greets them. Use the [cli](/ns/cli/1.0/) library to prompt and print. [Solution](./solution.html)



Now you're ready for [the next tutorial](/guides/tutorials/tutorial-3/).
