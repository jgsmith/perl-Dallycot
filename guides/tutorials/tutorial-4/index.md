---
title: "Tutorial 4: Traversing a Sequence"
breadcrumbs:
  - url: /guides/
    title: Guides
  - url: /guides/tutorials/
    title: Tutorials
---

Dallycot is designed to work with sequences of information. These can take the form of streams (linked lists), vectors (arrays), or sets.

Sequences drive iteration. Dallycot doesn't have the familiar for loop that you might know from languages like Java, Python, or Ruby. Instead, it focuses on a current element and then proceeds to the next element in a sequence.

Think of a sequence as a piece of yarn with beads knotted into it. For each bead, you want to do something and then move on to the next bead. When you run out of beads, you're done.

In Dallycot, you can access the current bead with the head operator (`'`). For example, if you have a sequence of numbers `[1, 2, 3]`, then the head of the sequence is the number `1`.

The rest of the sequence is called the tail and is accessed using the tail operator (`...`). For example, given the sequence `[1, 2, 3]`, the tail is `[2, 3]`. The tail is always another sequence. It's what you use to move to the next bead.

If we want to do the same thing for each bead on our yarn, then we need a way to start over, but with a new bead. Something like saying, "For the first bead, say something, then move to the rest of the beads and for the first bead, say something, then move to the ...". This is recursion: doing the same thing over and over again but with a different parameter each time (in this case, our set of beads which decreases by one each time around).

Written as a sequence of steps:

1. If we have any beads:
   1. say something,
   3. Start over with the rest of the beads.
2. Otherwise, we don't do anything.

Written as Dallycot:

```
if-we-have-any?(beads) :> ?beads;
say-something() :> print("Say something");

loop(beads) :> (
  (if-we-have-any?(beads)) : (
    say-something();
    loop(beads...)
  )
  ( ) : ( )
);
```

We can call it for a string of 20 beads with something like `loop(1..20)`.

A short way to write this would be:

```
loop(sequence) :> last({ print("Say something") } @ sequence);
```

<!-- Now you're ready for [the next tutorial](/guides/tutorials/tutorial-5/). -->
