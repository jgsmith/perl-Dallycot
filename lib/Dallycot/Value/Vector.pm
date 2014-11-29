package Dallycot::Value::Vector;
use strict;
use warnings;

use utf8;
use parent 'Dallycot::Value::Collection';

use Promises qw(deferred collect);

sub new {
  my($class, @values) = @_;
  $class = ref $class || $class;
  return bless \@values => $class;
}

sub calculate_length {
  my($self, $engine) = @_;

  my $d = deferred;

  $d -> resolve($engine->make_numeric(scalar @$self));

  return $d->promise;
}

sub calculate_reverse {
  my($self, $engine) = @_;

  my $d = deferred;

  $d -> resolve($self -> new(reverse @$self));

  return $d -> promise;
}

sub apply_map {
  my($self, $engine, $d, $transform) = @_;

  collect(
    map { $transform -> apply($engine, {}, $_) } @$self
  )->done(sub {
    my @values = map { @$_ } @_;
    $d -> resolve(bless \@values => __PACKAGE__);
  }, sub {
    $d -> reject(@_);
  });

  return;
}

sub apply_filter {
  my($self, $engine, $d, $filter) = @_;

  collect(
    map { $filter -> apply($engine, {}, $_) } @$self
  )->done(sub {
    my(@hits) = map { $_ -> value } map { @$_ } @_;
    my @values;
    for(my $i = 0; $i < @hits; $i++) {
      push @values, $self->[$i] if $hits[$i];
    }
    $d -> resolve(bless \@values => __PACKAGE__);
  }, sub {
    $d -> reject(@_);
  });

  return;
}

sub value_at {
  my($self, $engine, $index) = @_;

  my $d = deferred;

  if($index > @$self || $index < 1) {
    $d -> resolve($engine->UNDEFINED);
  }
  else {
    $d -> resolve($self->[$index-1]);
  }

  return $d -> promise;
}

sub head {
  my($self, $engine) = @_;

  my $d = deferred;

  if(@$self) {
    $d -> resolve($self->[0]);
  }
  else {
    $d -> resolve($engine -> UNDEFINED);
  }

  return $d -> promise;
}

sub tail {
  my($self, $engine) = @_;

  my $d = deferred;

  if(@$self) {
    $d -> resolve(bless [ @$self[1..$#$self] ] => __PACKAGE__);
  }
  else {
    $d -> resolve(bless [] => __PACKAGE__);
  }

  return $d -> promise;
}

sub reduce {
  my($self, $engine, $start, $lambda) = @_;

  my $promise = deferred;

  $self->_reduce_loop($engine, $promise,
    start => $start,
    lambda => $lambda,
    index => 0
  );

  return $promise->promise;
}

sub _reduce_loop {
  my($self, $engine, $promise, %params) = @_;

  my($start, $lambda, $index) = @params{qw(start lambda index)};

  if($index < @$self) {
    $lambda -> apply($engine, {}, $start, $self->[$index]) -> done(sub {
      my($next_start) = @_;
      $self->_reduce_loop($engine, $promise,
        start => $next_start,
        lambda => $lambda,
        index => $index+1
      );
    }, sub {
      $promise->reject(@_);
    });
  }
  else {
    $promise -> resolve($start);
  }
  return;
}

1;
