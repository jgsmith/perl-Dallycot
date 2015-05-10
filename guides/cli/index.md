---
title: Interactive Sessions
breadcrumbs:
  - url: /guides/
    title: Guides
---

The Dallycot distribution includes an interactive command line shell that can also be used to run Dallycot scripts. This shell is an easy way to experiment with Dallycot.

## Starting the Dallycot Shell

To start the Dallycot shell, you can type the following at your operating system prompt:

```shell
$ dallycot
Dallycot, version 0.150030.
Copyright (C) 2014 James Smith.
This is free software licensed under the same terms as Perl 5.
There is ABSOLUTELY NO WARRANTY; not even for MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.

Additional information about Dallycot is available at http://www.dallycot.net/.

Please contribute if you find this software useful.
For more information, visit http://www.dallycot.net/get-involved/.

in[1] :=
```

## A Dallycot Session

Dallycot uses a prompt of the form <code>in[<em>n</em>] :=</code> to tell you that it is ready to receive and evaluate input. You can type your input, ending with `Enter` or `Return`. Each time you provide input, <code><em>n</em></code> increments by one. Dallycot records your input in the `in` vector.

You don't enter the <code>in[<em>n</em>] :=</code> prompt. Dallycot provides that for you. Only type the text that follows it.

When you have entered your input, Dallycot processes it and prints the result prefixed with <code>out[<em>n</em>]</code>. Just as with your input, Dallycot records your results in the `out` vector.

```text
in[1] := sin(30)

out[1] := 1/2

```
