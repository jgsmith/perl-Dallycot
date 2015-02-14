Dallycot
========

[![Build Status](https://travis-ci.org/jgsmith/perl-Dallycot.svg?branch=master)](https://travis-ci.org/jgsmith/perl-Dallycot)

A linked open code engine.

See [Dallycot::Manual](./lib/Dallycot/Manual.pod) for more information.

## PerlTidy Options

```
perltidy -b -bext=/ -pbp -i=2 -ci=2 -l=108 -nst -nse -conv `find lib -name *.pm`
```

## PerlCritic Options

```
perlcritic -p perlcritic.rc `find lib -name *.pm`
```
