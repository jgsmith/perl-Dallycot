---
title: "Tutorial 3: Making a Decision"
breadcrumbs:
  - url: /guides/
    title: Guides
  - url: /guides/tutorials/
    title: Tutorials
---

Dallycot doesn't have the "if then else" statement familiar from other languages. Rather, it has a list of guarded expressions. Each guard is checked. As soon as a guard passes, the corresponding expression is used.

For example, consider the following set of guarded expressions:

```
(
  (x = 3) : x * 3
  (x = 2) : x + 3
  (x = 1) : x - 3
  (     ) : x * x
)
```

Dallycot will go through each one in turn. If `x` equals `3`, then the first will be selected and the others will be ignored. If `x` equals `2`, the first will be ignored, the second will be selected, and the others will be ignored. An so on. The last expression is unguarded. The empty parenthesis indicates that there is no guard for the corresponding expression.

This construct gives us the expressiveness of the "if then else" and the "given when" or "switch" constructions that we have in other languages.

Now you're ready for [the next tutorial](/guides/tutorials/tutorial-4/).
