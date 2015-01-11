package Dallycot::Library::Core;

# ABSTRACT: Core library of useful functions

use strict;
use warnings;

use utf8;

BEGIN {
  require Dallycot::Library::Core::Functions;
  require Dallycot::Library::Core::Math;
  require Dallycot::Library::Core::Linguistics;
  require Dallycot::Library::Core::Streams;
  require Dallycot::Library::Core::Strings;
}

1;
