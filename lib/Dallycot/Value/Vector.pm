package Dallycot::Value::Vector;

# RDF Sequence

use parent 'Dallycot::Value::Collection';

use Promises qw(deferred collect);

sub new {
  shift;
  bless \@_ => __PACKAGE__;
}

sub length {
  my($self, $engine, $d) = @_;

  $d -> resolve($engine->Number(scalar @$self));
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
}

sub value_at {
  my($self, $engine, $index) = @_;

  my $d = deferred;

  if($index > @$self || $index < 1) {
    $d -> resolve($engine->Undefined);
  }
  else {
    $d -> resolve($self->[$index-1]);
  }
  $d -> promise;
}

sub head {
  my($self, $engine) = @_;

  my $d = deferred;

  if(@$self) {
    $d -> resolve($self->[0]);
  }
  else {
    $d -> resolve($engine -> Undefined);
  }

  $d -> promise;
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

  $d -> promise;
}

sub reduce {
  my($self, $engine, $start, $lambda) = @_;

  my $promise = deferred;

  $self->_reduce_loop($engine, $promise, $start, $lambda, 0);

  $promise->promise;
}

sub _reduce_loop {
  my($self, $engine, $promise, $start, $lambda, $index) = @_;

  if($index < @$self) {
    $lambda -> apply($engine, {}, $start, $self->[$index]) -> done(sub {
      my($next_start) = @_;
      $self->_reduce_loop($engine, $promise, $next_start, $lambda, $index+1);
    }, sub {
      $promise->reject(@_);
    });
  }
  else {
    $promise -> resolve($start);
  }
}

1;
