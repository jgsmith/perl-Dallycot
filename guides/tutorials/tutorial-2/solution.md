---
title: "Solution to Tutorial 2: Simple input/output program"
breadcrumbs:
  - url: /guides/
    title: Guides
  - url: /guides/tutorials
    title: Tutorials
  - url: /guides/tutorials/tutorial-2
    title: Labels and Types
---

This program illustrations the following techniques:

- reading strings from the terminal
- labeling information
- combining two strings
- printing strings to the terminal

This program uses the command-line interface (CLI) library.

```
uses "http://www.dallycot.net/ns/cli/1.0#";
```

The first order of business is to prompt for the user's name. The `input-string` function accepts a prompt and returns the string that was typed in.

```
name := input-string("What is your name? ");
```

Now that we have a name, we can concatenate the name with the greeting.

```
greeting := "Hello, " ::> name ::> ".";
```

Finally, we print the greeting.

```
print(greeting);
```

This ends the program.
