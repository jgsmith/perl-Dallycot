package Dallycot::AST::Zip;

use strict;
use warnings;

use parent 'Dallycot::AST';

use Promises qw(collect);

use List::Util qw(max);
use List::MoreUtils qw(all any each_array);

sub to_string {
  my($self) = @_;
  return '(' . join(' Z ', map { $_ -> to_string } @{$self}) . ')'
}

sub execute {
  my($self, $engine, $d) = @_;

  # produce a vector with the head of each thing
  # then a tail promise for the rest
  # unless we're all vectors, in which case zip everything up now!
  if(any { $_ -> isa('Dallycot::AST') } @$self) {
    $engine -> collect(@$self) -> done(sub {
      my $newself = bless \@_ => __PACKAGE__;
      $newself -> execute($engine, $d);
    }, sub {
      $d -> reject(@_);
    });
  }
  elsif(all { $_ -> isa('Dallycot::Value::Vector') } @$self) {
    # all vectors
    my $it = each_arrayref(@$self);
    my @results;
    while(my @vals = $it->()) {
      push @results, bless \@vals => 'Dallycot::Value::Vector';
    }
    $d->resolve(bless \@results => 'Dallycot::Value::Vector');
  }
  elsif(all { $_ -> isa('Dallycot::Value::String') } @$self) {
    # all strings
    my @sources = map { \{$_->value} } @$self;
    my $length = max(map { length $$_ } @sources);
    my @results;
    for(my $idx = 0; $idx < $length; $idx ++) {
      my $s = join("", map { substr($$_, $idx, 1) } @sources);
      push @results, Dallycot::Value::String->new($s);
    }
    $d->resolve(bless \@results => 'Dallycot::Value::Vector');
  }
  else {
    collect(
      map { $_ -> head($engine) } @$self
    )->done(sub {
      my(@heads) = map { @$_ } @_;
      collect(
        map { $_ -> tail($engine) } @$self
      )->done(sub {
        my(@tails) = map { @$_ } @_;
        my $r;
        $d -> resolve(
          $r = bless [
            (bless \@heads => 'Dallycot::Value::Vector'),

            undef,

            Dallycot::Value::Lambda->new(
              (bless \@tails => __PACKAGE__),
              [],
              [],
              {}
            )
          ] => 'Dallycot::Value::Stream'
        );
      }, sub {
        $d -> reject(@_);
      })
    }, sub {
      $d -> reject(@_);
    });
  }

  return;
}

1;
