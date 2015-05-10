---
title: Tutorials
breadcrumbs:
  - url: /guides/
    title: Guides
---

The best way to learn how to write is by trying to imitate the best thigs you've read. These tutorials encourage you to learn Dallycot by imitating what you read here.

The tutorials use `dallycot` in its [interactive](/guides/cli) and execution modes. Each part of a tutorial will let you know which mode it expects you to use.

When using the interactive mode, `dallycot` will run a startup script to set up initial parameters. The tutorials assume you have the following in your `~/.dallycot` file:

```
uses "http://www.dallycot.net/ns/core/1.0#";
uses "http://www.dallycot.net/ns/linguistics/1.0#";
uses "http://www.dallycot.net/ns/math/1.0#";
uses "http://www.dallycot.net/ns/streams/1.0#";
uses "http://www.dallycot.net/ns/strings/1.0#";
```

Interactive mode will automatically add the command line interface library to this list.

## Tutorial Conventions

| Style | Use |
| Normal text | Tutorial narrative and explanitory text |
| `monospace` | Code fragments or blocks; variable, program, or function names |
| <u><code>underlined monospace</code></u> | Text you enter at a command prompt |
| <strong>`bold monospace`</strong> | Result of running a command in `dallycot` |

## Tutorials

1. [Hello world](./tutorial-1/)
2. [Labels and Types](./tutorial-2/)
2. [Making a Decision](./tutorial-3/)
3. [Traversing a Sequence](./tutorial-4/)
