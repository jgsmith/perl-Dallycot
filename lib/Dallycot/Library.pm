package Dallycot::Library;

# ABSTRACT: Base for adding namespaced functions to Dallycot.

=head1 SYNOPSIS

   package MyLibrary;

   use Moose;
   extends 'Dallycot::Library';

   ns 'http://www.example.com/library#';

   define foo => << 'EOD';
     (a, b) :> ((a * b) mod (b - a))
   EOD

   define bar => sub {
     my($library, $engine, $options, @params) = @_;
     # Perl implementation
   };

=cut

use strict;
use warnings;

use utf8;
use MooseX::Singleton;

use MooseX::Types::Moose qw/ArrayRef CodeRef/;
use Carp qw(croak);

use Dallycot::Parser;
use Dallycot::Processor;

use AnyEvent;

use Moose::Exporter;

use Promises qw(deferred collect);

my %engines;

sub ns {
  my($meta, $uri) = @_;

  Dallycot::Registry->instance->register_namespace($uri, $meta->{'package'});

  no strict 'refs';

  ${$meta->{'package'}.'::NAMESPACE'} = $uri;
  ${$meta->{'package'}.'::NAMESPACE'} = $uri;

  my $engine = $engines{$meta->{'package'}} ||= Dallycot::Processor->new;
  $engine -> append_namespace_search_path($uri);
  return;
}

sub namespace {
  my($class) = @_;

  $class = ref($class) || $class;

  no strict 'refs';

  return ${$class . "::NAMESPACE"};
}

sub define {
  my($meta, $name, @options) = @_;

  my $body = pop @options;
  my %options = @options;

  no strict 'refs';

  my $definitions = \%{$meta->{'package'}.'::DEFINITIONS'};
  $definitions = \%{$meta->{'package'}.'::DEFINITIONS'};

  if(is_CodeRef($body)) {
    # Perl subroutine
    #$meta -> add_method( 'run_' . $name, $body );
    $definitions->{$name} = {
      %options,
      coderef => $body
    };
  }
  else {
    # Dallycot source
    my $parser = Dallycot::Parser->new;
    my $parsed = $parser -> parse($body);
    my $engine = $engines{$meta->{'package'}} ||= Dallycot::Processor->new;
    my $cv = AnyEvent -> condvar;

    if(!$parsed) {
      croak "Unable to parse Dallycot source for $name";
    }

    $engine->with_child_scope->execute(@{$parsed})->done(sub {
      my($expr) = @_;
      #$engine -> add_assignment($name, $expr);
      $definitions->{$name} = {
        %options,
        expression => $expr
      };
      $cv -> send();
    }, sub {
      my($err) = @_;
      $cv -> croak("Unable to define $name: $err for $body\n");
    });

    $cv -> recv;
  }
  return;
}

sub uses {
  my($meta, @uris) = @_;

  my $engine = $engines{$meta->{'package'}} ||= Dallycot::Processor->new;
  $engine -> append_namespace_search_path(@uris);
  return;
}

Moose::Exporter -> setup_import_methods(
  with_meta => [
    qw(ns define uses)
  ],
  also => 'Moose',
);

sub init_meta {
  my( undef, %p ) = @_;

  my $meta = MooseX::Singleton -> init_meta(%p);
  $meta -> superclasses(__PACKAGE__);
  return $meta;
}

sub has_assignment {
  my($self, $name) = @_;

  my $def = $self -> get_definition($name);
  return defined($def) && keys %$def;
}

sub get_assignment {
  my($self, $name) = @_;

  my $class = ref($self) || $self;


  my $def = $self -> get_definition($name);

  return unless defined $def && keys %$def;
  if($def -> {expression}) {
    return $def -> {expression};
  }
  else {
    return $self->_uri_for_name($name);
  }
}

sub _uri_for_name {
  my($class, $name) = @_;

  $class = ref($class) || $class;

  # return Dallycot::Value::URI -> new(${$class.'::NAMESPACE'} . $name);
  return Dallycot::Value::URI->new($class->namespace . $name);
}

sub get_definition {
  my($class, $name) = @_;

  return unless defined $name;

  $class = ref($class) || $class;

  no strict 'refs';

  my $definitions = \%{$class."::DEFINITIONS"};

  if(exists $definitions->{$name} && defined $definitions->{$name}) {
    return $definitions->{$name};
  }
  else {
    return;
  }
}

sub min_arity {
  my($self, $name) = @_;

  my $def = $self->get_definition($name);

  if(!$def) {
    return 0;
  }

  if($def -> {coderef}) {
    if(defined($def->{arity})) {
      if(is_ArrayRef($def->{arity})) {
        return $def->{arity}->[0];
      }
      else {
        return $def->{arity};
      }
    }
    else {
      return 0;
    }
  }
  else {
    return 0;
  }
}

sub _is_placeholder {
  my( $self, $obj ) = @_;

  return blessed($obj) && $obj->isa('Dallycot::AST::Placeholder');
}

sub apply {
  my($self, $name, $parent_engine, $options, @bindings) = @_;

  my $def = $self->get_definition($name);

  if(!$def) {
    my $d = deferred;
    $d -> reject("$name is undefined.");
    return $d -> promise;
  }

  if($def -> {coderef}) {
    my $engine = $parent_engine -> with_child_scope;
    if(defined $def -> {arity}) {
      if(is_ArrayRef($def->{arity})) {
        if($def->{arity}->[0] > @bindings || (@{$def->{arity}} > 1 && @bindings > $def->{arity}->[1])) {
          my $d = deferred;
          $d -> reject("Expected " . $def->{arity}->[0] . " to " . $def->{arity}->[1] . " arguments but found " . scalar(@bindings));
          return $d -> promise;
        }
      }
      elsif($def->{arity} != @bindings) {
        my $d = deferred;
        $d -> reject("Expected " . $def->{arity} . " argument(s)s but found " . scalar(@bindings));
        return $d -> promise;
      }
    }
    # we look for placeholders and return a lambda if there are any
    if( grep { $self->_is_placeholder($_) } @bindings ) {
      my(@filled_bindings, @filled_identifiers, @args, @new_args);
      foreach my $binding (@bindings) {
        if($self -> _is_placeholder($binding)) {
          push @new_args, '__arg_'.$#args;
          push @args, '__arg_'.$#args;
        }
        else {
          push @filled_identifiers, '__arg_'.$#args;
          push @args, '__arg_'.$#args;
          push @filled_bindings, $binding;
        }
      }
      my $d = deferred;
      $engine-> collect( @filled_bindings ) -> done(sub {
        my(@collected_bindings) = @_;
        collect( map { $engine -> execute($_) } values %$options ) -> done(sub {
          my(@new_values) = @_;
          my %new_options;
          @new_options{keys %$options} = @new_values;
          $d -> resolve(Dallycot::Value::Lambda->new(
            expression => Dallycot::AST::Apply->new(
              $self->_uri_for_name($name),
              [ map { bless [ $_ ] => 'Dallycot::AST::Fetch' } @args ],
            ),
            bindings => \@new_args,
            options => \%new_options,
            closure_environment => {
              map { $filled_identifiers[$_] => $collected_bindings[$_] } (0..$#filled_identifiers)
            }
          ));
        }, sub {
          $d -> reject(@_);
        });
      }, sub {
        $d -> reject(@_);
      });
      return $d -> promise;
    }
    elsif($def -> {hold}) {
      return $def->{coderef}->($engine, $options, @bindings);
    }
    else {
      my $d = deferred;
      $engine -> collect( @bindings ) -> done(sub {
        my(@collected_bindings) = @_;
        collect( map { $engine -> execute($_) } values %$options ) -> done(sub {
          my(@new_values) = @_;
          my %new_options;
          @new_options{keys %$options} = @new_values;
          my $lib_promise = eval {
            $def->{coderef}->($engine, \%new_options, @collected_bindings);
          };
          if($@) {
            $d -> reject($@);
          }
          elsif($lib_promise) {
            $lib_promise->done(sub {
              $d -> resolve(@_);
            }, sub {
              $d -> reject(@_);
            });
          }
          else {
            $d -> reject("Unable to call $name");
          }
        }, sub {
          $d -> reject(@_);
        });
      }, sub {
        $d -> reject(@_);
      });
      return $d -> promise;
    }
  }
  elsif($def -> {expression}) {
    my $engine = $parent_engine -> with_child_scope;
    return $def -> {expression} -> apply($engine, $options, @bindings);
  }
  else {
    my $d = deferred;
    $d -> reject("Value is not a lambda");
    return $d -> promise;
  }
}

1;
