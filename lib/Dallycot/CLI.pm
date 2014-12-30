package Dallycot::CLI;

use Moose;
with 'MooseX::Getopt::Usage';


use Term::ReadLine;
use Mojo;
use AnyEvent;
use Promises backend => ['AnyEvent'];

use Dallycot::Parser;
use Dallycot::Processor;

BEGIN {
  require Dallycot::Library::Core;
}

has '_parser' => (
  accessor => 'parser',
  default => sub { Dallycot::Parser -> new }
);

has '_engine' => (
  accessor => 'engine',
  default => sub { Dallycot::Processor -> new }
);

has '_term' => (
  accessor => 'term'
);

has '_prompt' => (
  accessor => 'prompt',
  default => 'in[%d] := ',
);

has '_deep_prompt' => (
  accessor => 'deep_prompt',
  default => '>>> ',
);

has '_screen' => (
  accessor => 'screen'
);

sub run {
  my($app) = @_;

  $app->term(Term::ReadLine->new('Dallycot Prompt'));
  $app->screen($app->term->OUT || \*STDOUT);

  my $OUT = $app->screen;

  # load .dallycot
  $app -> run_file($ENV{'HOME'} . "/.dallycot");

  my $parse;
  my $stmt_counter = 1;
  my($in, $out);
  $app->engine->add_assignment('in', $in = Dallycot::Value::Vector->new);
  $app->engine->add_assignment('out', $out = Dallycot::Value::Vector->new);

  while( defined ($_ = $app->term->readline(sprintf($app->prompt, $stmt_counter) ) ) ) {
    my $line = $_;
    $parse = $app->parser->parse($line);
    while((!defined($parse) || @$parse == 1 && $parse->[0]->isa('Dallycot::AST::Expr')) && !$app->parser->error) {
      $_ = $app -> term -> readline($app->deep_prompt);
      if(!defined($_)) {
        $parse = undef;
        last;
      }
      $line .= "\n" . $_;
      $parse = $app->parser->parse($line);
    }
    ${$in}[$stmt_counter-1] = Dallycot::Value::String->new($line);
    $app->term->addhistory($line);
    if($app->parser->error) {
      print $OUT $app->parser->error;
    }
    elsif(defined $parse) {
      my $ret = $app -> execute($parse);
      if(defined $ret) {
        print $OUT "out[$stmt_counter] := " . $ret->as_text . "\n";
        ${$out}[$stmt_counter-1] = $ret;
      }
    }
    print $OUT "\n";
    $stmt_counter ++;
  }
  print $OUT "\n";
}

sub run_file {
  my($app, $filename) = @_;

  if(-f $filename) {
    open my $file, "<", $filename or die "Unable to read $filename\n";
    local($/) = undef;
    my $source = <$file>;
    close $file;
    my $parse = $app->parser->parse($source);
    if($parse) {
      $app->execute($parse);
    }
  }
}

sub execute {
  my($app, $parse) = @_;
  my $cv = AnyEvent -> condvar;

  eval {
    if('HASH' eq $parse) {
      $parse = [ $parse ];
    }
    $app -> engine -> max_cost(1_000_000);
    $app -> engine -> cost(0);
    $app -> engine -> execute(@{$parse}) -> done(
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
    my $err = $@;
    while($err =~ s{\s+at\s.+?\sline\s+\d+.*?$}{}x) {
      # noop
    }

    my $OUT = $app -> screen;
    print $OUT '*** ' . $err . "\n";
  }
  $ret;
}

1;
