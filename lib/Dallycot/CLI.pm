package Dallycot::CLI;

# ABSTRACT: command line interface application

use Moose;
with 'MooseX::Getopt';

use Mojo;
use AnyEvent;
use Promises qw(deferred), backend => ['AnyEvent'];

use Dallycot;
use Dallycot::Parser;
use Dallycot::Processor;
use Dallycot::Channel::Terminal;

my $has_tangle = eval {
  require Dallycot::Tangle;
  1;
};

if($@) { print STDERR "$@\n"; }


BEGIN {
  require Dallycot::Library;
  Dallycot::Library -> libraries;
}

has 'c' => (
  is => 'ro',
  isa => 'Bool',
  documentation => 'check syntax only (parses but does not execute)',
);

has 'S' => (
  is => 'ro',
  isa => 'Bool',
  documentation => 'look for programfile using PATH environment variable'
);

has 'v' => (
  is => 'ro',
  isa => 'Bool',
  documentation => 'print version and licensing banner and exit',
);

has 'V' => (
  is => 'ro',
  isa => 'Bool',
  documentation => 'print installed namespaces and exit',
);

has '_parser' => (
  accessor => 'parser',
  default => sub { Dallycot::Parser -> new }
);

has '_engine' => (
  accessor => 'engine',
  default => sub { Dallycot::Processor -> new }
);

has '_channel' => (
  accessor => 'channel',
);

has '_prompt' => (
  accessor => 'prompt',
  default => 'in[%d] := ',
);

has '_deep_prompt' => (
  accessor => 'deep_prompt',
  default => '>>> ',
);

has '_statement_counter' => (
  accessor => 'statement_counter',
  default => 1,
  isa => 'Int'
);

has '_done' => (
  accessor => 'done',
);

sub check {
  my($self) = @_;
  return $self -> c;
}

sub run {
  my($app) = @_;

  $app->channel(Dallycot::Channel::Terminal->new);

  if($app -> v) {
    $app -> print_banner;
    my $d = deferred;
    $d -> resolve(undef);
    return $d -> promise;
  }

  if($app -> V) {
    $app -> print_library_namespaces;
    my $d = deferred;
    $d -> resolve(undef);
    return $d -> promise;
  }

  $app -> engine
       -> create_channel('$OUTPUT', $app->channel);

  $app -> engine
       -> create_channel('$INPUT', $app->channel);

  my @args = @{$app -> extra_argv};

  if(@args) {
    return $app -> run_files(@args);
  }

  my $d = deferred;

  $app -> done($d);

  $app -> print_banner;

  # load .dallycot - but no error if it doesn't exist
  $app -> run_file($ENV{'HOME'} . "/.dallycot", 1) -> done(sub {
    my($in, $out);

    $app -> engine
         -> append_namespace_search_path($Dallycot::Library::CLI::NAMESPACE);

    $app -> engine
         -> add_assignment('in', $in = Dallycot::Value::Vector->new);

    $app -> engine
         -> add_assignment('out', $out = Dallycot::Value::Vector->new);

    $app->primary_prompt;
  }, sub {
    print STDERR "*** ", @_, "\n";
  });

  return $d -> promise;
}

sub print_banner {
  my($app) = @_;

  my $out = $app -> channel;

  $Dallycot::VERSION //= 'm.xxyyyz';
  $out -> send(
    "Dallycot, version $Dallycot::VERSION.\n",
    "Copyright (C) 2014 James Smith.\n",
    "This is free software licensed under the same terms as Perl 5.\n",
    "There is ABSOLUTELY NO WARRANTY; not even for MERCHANTABILITY or\n",
    "FITNESS FOR A PARTICULAR PURPOSE.\n\n",
    "Additional information about Dallycot is available at http://www.dallycot.net/.\n\n",
    "Please contribute if you find this software useful.\n",
    "For more information, visit http://www.dallycot.net/get-involved/.\n"
  );
}

sub print_library_namespaces {
  my($app) = @_;

  my %namespaces;

  foreach my $lib (Dallycot::Library -> libraries) {
    $namespaces{$lib -> instance -> namespace} = $lib;
  }

  my $out = $app -> channel;

  if(keys %namespaces) {
    $out -> send("The following namespaces are installed:\n");
  }
  else {
    $out -> send("No namespaces are installed\n");
  }

  foreach my $ns (sort keys %namespaces) {
    $out -> send("  $ns\n");
  }
}

sub run_files {
  my( $app, @files ) = @_;

  my $d = deferred;

  $app -> _run_files($d, @files);

  return $d -> promise;
}

sub _run_files {
  my( $app, $d, $file, @files) = @_;

  $app -> run_file($file)->done(sub {
    if(@files) {
      $app -> _run_files($d, @files);
    }
    else {
      $d -> resolve();
    }
  }, sub {
    $d -> reject(@_);
  });
}

sub primary_prompt {
  my($app) = @_;

  $app -> channel
       -> receive(
            prompt => Dallycot::Value::String->new(
              sprintf("\n".$app->prompt, $app->statement_counter)
            )
          )
       -> done(sub {
         my($line) = @_;
         if($line -> isa('Dallycot::Value::String')) {
           if($line -> value =~ m{^\s*$}) {
             $app -> add_history($line);
             $app -> primary_prompt;
           }
           else {
             $app -> check_parse($line);
           }
         }
         else { #if($line -> isa('Dallycot::Value::Undefined')) {
           $app -> channel -> send("\n");
           $app -> done -> resolve(undef);
         }
       }, sub {
         my($err) = @_;
         $app -> channel -> send("*** $err\n");
         $app -> done -> resolve(undef);
       });
}

sub check_parse {
  my( $app, $line ) = @_;

  my $parse = $app->parser->parse($line->value);
  if(!defined($parse)
     || @$parse == 1
        && $parse->[0]->isa('Dallycot::AST::Expr')
        && !$app->parser->error
  ) {
    $app->secondary_prompt($line);
  }
  else {
    $app -> process_line($line, $parse);
  }
}

sub secondary_prompt {
  my($app, $line) = @_;

  $app -> channel
       -> receive(
            prompt => Dallycot::Value::String->new($app -> deep_prompt)
          )
       -> done(sub {
         my($next_line) = @_;
         if($next_line -> is_defined) {
           $line = Dallycot::Value::String->new($line->value . "\n" . $next_line -> value);
           $app -> check_parse($line);
         }
         else {
           $app -> process_line($line, undef);
         }
       });
}

sub add_history {
  my( $app, $line ) = @_;

  my $in = $app -> engine -> get_assignment('in');
  my $stmt_counter = $app -> statement_counter;
  $app -> statement_counter($app -> statement_counter + 1);
  $app -> channel -> add_history($line);

  ${$in}[$stmt_counter-1] = $line;
  return $stmt_counter;
}

sub process_line {
  my( $app, $line, $parse ) = @_;

  my $stmt_counter = $app -> add_history($line);

  if($app -> parser -> error) {
    $app -> channel -> send($app->parser->error);
    $app -> primary_prompt;
  }
  elsif(defined $parse) {
    $app -> execute($parse) -> then(sub {
      my($ret) = @_;
      if(defined $ret) {
        $app -> channel
             -> send("\nout[$stmt_counter] := ", $ret -> as_text);
        my $out = $app->engine->get_assignment('out');
        ${$out}[$stmt_counter-1] = $ret;
      }
    }, sub {
      my($error) = @_;
      $app -> channel -> send("*** $error\n");
    }) -> finally(sub {
      $app -> channel -> send("\n");
      $app -> primary_prompt;
    })->done(sub{});
  }
  else {
    $app -> channel -> send("\n");
    $app -> primary_prompt;
  }
}

sub run_file {
  my($app, $filename, $ignore_existance) = @_;

  my $file;
  if($app -> S) {
    my @dirs = (split(/:/, $ENV{PATH}), '.');
    $file = shift(@dirs) . '/' . $filename;
    while(!-f $file && @dirs) {
      $file = shift(@dirs) . '/' . $filename;
    }
  }
  else {
    $file = $filename;
  }
  if(-f $file) {
    open my $file, "<", $file or do {
      my $d = deferred;
      $d -> reject("Unable to read $filename");
      return $d -> promise;
    };
    local($/) = undef;
    my $source = <$file>;
    close $file;
    if($filename =~ m{\.md$}) {
      if($has_tangle) {
        $source = Dallycot::Tangle->new->parse($source);
      }
      else {
        my $d = deferred;
        $d -> reject("Unable to parse markdown: Markdent or its prerequisites are not installed");
        return $d -> promise;
      }
    }
    my $parse = $app->parser->parse($source);
    if($app->parser->warnings) {
      $app->channel->send("Warnings:\n  " . join("\n  ", $app->parser->warnings)."\n");
    }
    if(!$parse) {
      my $err = $app->parser->error;
      my $d = deferred;
      if($err) {
        $d -> reject("In $filename:\n$err");
      }
      else {
        $d -> reject("Unable to parse $filename");
      }
      return $d -> promise;
    }
    elsif(!$app->check) {
      return $app->execute($parse);
    }
  }
  elsif(!$ignore_existance) {
    my $d = deferred;
    $d -> reject("Unable to read $filename");
    return $d -> promise;
  }
  else {
    my $d = deferred;
    $d -> resolve(undef);
    return $d -> promise;
  }
}

sub execute {
  my($app, $parse) = @_;

  my $d = eval {
    if('HASH' eq $parse) {
      $parse = [ $parse ];
    }
    $app -> engine -> max_cost(1_000_000);
    $app -> engine -> cost(0);
    return $app -> engine -> execute(@{$parse}) -> catch(sub {
      my($err) = @_;
      while($err =~ s{\s+at\s.+?\sline\s+\d+.*?$}{}x) {
        # noop
      }

      $app->channel->send('*** ' . $err . "\n");
    });
  };
  if($d) {
    return $d;
  }
  elsif($@) {
    my $err = $@;
    while($err =~ s{\s+at\s.+?\sline\s+\d+.*?$}{}x) {
      # noop
    }

    $app->channel->send('*** ' . $err . "\n");
  }
  else {
    $app -> channel -> send('*** Unable to execute\n');
  }
  $d = deferred;
  $d -> resolve();
  return $d -> promise;
}

1;