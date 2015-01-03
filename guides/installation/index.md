---
title: Installation
breadcrumps:
  - url: /guides/
    title: Guides
---

Dallycot is distributed as a Perl package. Installing Dallycot is straightforward.

## Installation with `cpanm`

If you have `cpanm`, you only need one line:

```shell
% cpanm Dallycot
```

If you are installing into a system-wide directory, you may need to pass the `-S` flag to `cpanm`, which uses `sudo` to install the module:

```shell
% cpanm -S Dallycot
```

## Installing with the CPAN shell

Alternatively, if your CPAN shell is set up, you should just be able to do:

```shell
% cpan Dallycot
```

## Manual installation

As a last resort, you can manually install it. Download the tarball, untar it, then build it:

```shell
% perl Makefile.PL
% make && make test
```

Then install it:

```shell
% make install
```

If you are installing into a system-wide directory, you may need to run:

```shell
% sudo make install
```

## Documentation

You probably want the documentation and examples available on the [Dallycot website](http://www.dallycot.net/) if you aren't mucking around in the Dallycot innards or writing Perl-based extension libraries. The Perl-level Dallycot documentation is available as POD. You can run `perldoc` from a shell to read the documentation:

```shell
% perldoc Dallycot
% perldoc Dallycot::Manual
```
