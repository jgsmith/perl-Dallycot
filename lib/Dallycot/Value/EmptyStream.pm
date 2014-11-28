package Dallycot::Value::EmptyStream;

use parent 'Dallycot::Value::Collection';

use Promises qw(deferred);

sub new {
  bless [] => __PACKAGE__;
}

sub is_defined { 0 }

sub apply_map {
  my($self, $engine, $d, $transform) = @_;

  $d->resolve($self->new);
}

sub value_at {
  my $p = deferred;

  $p -> resolve(Dallycot::Value::Undefined->new);

  $p -> promise;
}

sub head {
  my $p = deferred;

  $p -> resolve(Dallycot::Value::Undefined->new);

  $p -> promise;
}

sub tail {
  my $p = deferred;

  $p -> resolve($_[0]->new);

  $p -> promise;
}

sub reduce {
  my($self, $engine, $start, $lambda) = @_;

  my $p = deferred;

  $p -> resolve($start);

  $p -> promise;
}

1;
