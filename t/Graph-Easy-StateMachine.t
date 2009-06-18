# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Graph-Easy-StateMachine.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More;
BEGIN { plan tests => 10 };
use Graph::Easy;
use Graph::Easy::StateMachine;
ok(1); # If we made it this far, we're ok.

  my $graph = Graph::Easy->new( <<FSA );
      [ START ] => [ disconnected ]
      = goodconnect => [ inprogress ]
      = goodconnect => [ connected ]
      = sentrequest => [ requestsent ]
      = readresponse => [ haveresponse ]
      = done => [ END ]
      # Try pasting this into the form
      # at http://bloodgate.com/graph-demo
      [ disconnected ], [ inprogress ], [connected ] ,
      [ requestsent ] , [ haveresponse ]
      -- whoops --> [FAIL]
FSA
  my $code = $graph->as_FSA( base => 'bibbity');
#   warn $code;
  ok(eval  $code);
  my $boo = bless [], 'bibbity::START';
  ok($boo->disconnected);
  ok($boo->goodconnect);
  is(ref($boo), 'bibbity::inprogress');
  ok($boo->goodconnect);
  is(ref($boo), 'bibbity::connected');
  

  use Graph::Easy::StateMachine <<FSA ;
      [BASE] -> [ START ] = goA => [ A ]
      [ A ] = goB => [ B ]
      [ START ] = goB => [ B ]
FSA
  my $w = bless {};

  ok($w->START);
  is('main::B', ref ($w->goA->goB), "chaining");
  eval { $w->START };
  ok ( $@ =~ m/invalid state transition B->START/ );





