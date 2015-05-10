---
title: "Tutorial 1: Hello World"
breadcrumbs:
  - url: /guides/
    title: Guides
  - url: /guides/tutorials/
    title: Tutorials
---

## Interactive mode

In interactive mode, we start up with the ability to interact with the terminal, so printing something like "Hello World" is simple enough:

<pre><code>% <u>dallycot</u>
Dallycot, version 0.150660.
Copyright (C) 2014-2015 James Smith.
This is free software licensed under the same terms as Perl 5.
There is ABSOLUTELY NO WARRANTY; not even for MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.

Additional information about Dallycot is available at http://www.dallycot.net/.

Please contribute if you find this software useful.
For more information, visit http://www.dallycot.net/get-involved/.

in[1] := <u>print("Hello World")</u>
<strong>Hello World</strong>

out[1] := <strong>true</strong>

in[2] := <u> </u></code></pre>

## Script

Open up your favorite plain text editor and create a new file (we'll call it `hello-world.md` for the rest of this tutorial) with the following content (the <code>`</code> is not the single or double quote mark [`'` or `"`] ):

    # Hello World

    A simple "Hello World" example.

    ```
    uses "http://www.dallycot.net/ns/cli/1.0#";

    print("Hello World");
    ```

Save this and then run the following in your terminal:

<pre><code>% <u>dallycot hello-world.md</u>
<strong>Hello World</strong>
% <u> </u></code></pre>


Dallycot uses markdown to invert the relationship between code and commentary. In most programming languages, the code is the primary driver behind the structure of the file content. With markdown (and literate programming practices), the commentary (or narrative) drives the file structure.

Markdown files are the preferred format for writing Dallycot scripts. Markdown lets you write a narrative of what you want to do before writing the code or as you write the code.

Now you're ready for [the next tutorial](/guides/tutorials/tutorial-2/).
