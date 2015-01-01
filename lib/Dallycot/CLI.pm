package Dallycot::CLI;

use Moose;
with 'MooseX::Getopt';


use Mojo;
use AnyEvent;
use Promises qw(deferred), backend => ['AnyEvent'];

use Dallycot;
use Dallycot::Parser;
use Dallycot::Processor;
use Dallycot::Channel::Terminal;

BEGIN {
  require Dallycot::Library::Core;
  require Dallycot::Library::CLI;
}

has 'c' => (
  is => 'ro',
  isa => 'Bool',
  documentation => 'check syntax only (parses but does not execute)',
);

has 'v' => (
  is => 'ro',
  isa => 'Bool',
  documentation => 'print version number and exit',
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

  if($app -> v) {
    print STDERR "Dallycot version $Dallycot::VERSION\n";
    my $d = deferred;
    $d -> resolve(undef);
    return $d -> promise;
  }

  my @args = @{$app -> extra_argv};

  if(@args) {
    return $app -> run_files(@args);
  }

  my $d = deferred;

  $app -> done($d);

  $app->channel(Dallycot::Channel::Terminal->new);

  # load .dallycot - but no error if it doesn't exist
  $app -> run_file($ENV{'HOME'} . "/.dallycot", 1) -> done(sub {
    my($in, $out);

    $app -> engine
         -> append_namespace_search_path($Dallycot::Library::CLI::NAMESPACE);

    $app -> engine
         -> add_assignment('in', $in = Dallycot::Value::Vector->new);

    $app -> engine
         -> add_assignment('out', $out = Dallycot::Value::Vector->new);

    $app -> engine
         -> create_channel('$OUTPUT', $app->channel);

    $app->primary_prompt;
  }, sub {
    print STDERR "*** ", @_, "\n";
  });

  return $d -> promise;
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
              sprintf($app->prompt, $app->statement_counter)
            )
          )
       -> done(sub {
         my($line) = @_;
         if($line -> is_defined) {
           $app -> check_parse($line);
         }
         else {
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

sub process_line {
  my( $app, $line, $parse ) = @_;

  my $in = $app -> engine -> get_assignment('in');
  my $stmt_counter = $app -> statement_counter;
  $app -> statement_counter($app -> statement_counter + 1);

  ${$in}[$stmt_counter-1] = $line;
  $app -> channel -> add_history($line);
  if($app -> parser -> error) {
    $app -> channel -> send($app->parser->error);
  }
  elsif(defined $parse) {
    $app -> execute($parse) -> then(sub {
      my($ret) = @_;
      if(defined $ret) {
        $app -> channel
             -> send("out[$stmt_counter] := ", $ret -> as_text, "\n");
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


  if(-f $filename) {
    open my $file, "<", $filename or do {
      my $d = deferred;
      $d -> reject("Unable to read $filename");
      return $d -> promise;
    };
    local($/) = undef;
    my $source = <$file>;
    close $file;
    my $parse = $app->parser->parse($source);
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
