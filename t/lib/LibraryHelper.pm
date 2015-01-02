package LibraryHelper;

use strict;
use warnings;

use Test::More;
use AnyEvent;
use Promises backend => ['AnyEvent'];

use Dallycot::Processor;
use Dallycot::Parser;

use Exporter 'import';

our @EXPORT = qw(
  run
  uses
  Numeric
  Boolean
  String
  Vector
  Stream
);

my $processor = Dallycot::Processor -> new(
  context => Dallycot::Context -> new
);

my $parser = Dallycot::Parser -> new;

sub uses {
  my(@urls) = @_;

  $processor -> append_namespace_search_path(@urls);
  return;
}

sub run {
  my($stmt) = @_;
  my $cv = AnyEvent -> condvar;

  eval {
    my $parse = $parser -> parse($stmt);
    if('HASH' eq $parse) {
      $parse = [ $parse ];
    }
    $processor -> max_cost(100000);
    $processor -> cost(0);
    $processor -> execute(@{$parse}) -> done(
      sub { $cv -> send( @_ ) },
      sub { $cv -> croak( @_ ) }
    );
  };

  if($@) {
    $cv -> croak($@);
  }

  my $ret = eval {
    $cv -> recv;
  };
  if($@) {
    warn "$stmt: $@";
  }
  #print STDERR "Cost of running ($stmt): ", $processor -> cost, "\n";
  $ret;
}

sub Numeric {
  Dallycot::Value::Numeric -> new($_[0]);
}

sub Boolean {
  Dallycot::Value::Boolean -> new($_[0]);
}

sub String {
  Dallycot::Value::String->new(@_);
}

sub Vector {
  Dallycot::Value::Vector->new(@_);
}

sub Stream {
  my(@things) = @_;

  my $stream = Dallycot::Value::Stream -> new(pop @things);
  foreach my $thing (reverse @things) {
    $stream = Dallycot::Value::Stream -> new($thing, $stream);
  }
  return $stream;
}

1;
