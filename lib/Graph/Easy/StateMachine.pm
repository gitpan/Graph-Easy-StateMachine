package Graph::Easy::StateMachine;

use 5.006002;
use strict;
use warnings;

our $VERSION = '0.03';

our $base;
sub template($$$){
   my ($source, $dest, $edgelabel) = @_;
   "sub $source\::$edgelabel { bless \$_[0], '$dest' }"
};

use Graph::Easy;

sub Graph::Easy::as_FSA {
   my $graph = shift;
   my %attr = (base => (scalar caller()), BASESTATE => 'BASE', @_);
   my $base = $attr{base};
   my $BASE = $attr{BASESTATE};
   my @LOC;
   my %BaseTransitions;
   my %Transitions;
   for my $node ( $graph->nodes )
   {
      my $statename = $node->name;
      $statename eq $BASE or
         push @LOC, "push \@$base\::$statename\::ISA, qw( $base );";

      for my $edge ( $node->edges )
      {
         $edge->from->name eq $statename or next;
         my $from = $statename;
         my $to = $edge->to->name;
         my $frompack;
         if( $from eq $BASE )
         {
            $frompack = $base;
            $BaseTransitions{ $edge->name ||  $to } = 1;
         }else{
            $frompack = "$base\::$from";
         };
         my $topack = ( $to eq $BASE ? $base : "$base\::$to" );
         $Transitions{ $edge->name ||  $to }->{$from} = 1;
         push @LOC, template $frompack, $topack, $edge->name ||  $to;
         if ($edge->bidirectional)
         {
            $Transitions{ $edge->name ||  $from }->{$to} = 1;
            push @LOC, template $topack, $frompack, $edge->name || $from;
            $to eq $BASE and 
               $BaseTransitions{ $edge->name ||  $from } = 1;
         }
      };
   
   };
   for my $node ( $graph->nodes )
   {
      my $statename = $node->name;
      $statename eq $BASE and next;
      for my $method ( keys %BaseTransitions )
      {
          $Transitions{ $method }->{$statename} and next;
          push @LOC,
            "sub $base\::$statename\::$method { my (\$p,\$f,\$l) = caller; die qq{invalid state transition $statename\->$method at \$f line \$l\n} }"
      }
   }; 
   join "\n", @LOC, '1;';
}

sub import {
   shift; # lose package
   my $caller = caller;
   for (@_){
      my $g = Graph::Easy->new( $_ );
      eval $g->as_FSA(base => $caller) or die "FSA parse failure: $@"
   }; 
};

1;
__END__

=head1 NAME

Graph::Easy::StateMachine - create a FSA framework from a Graph::Easy graph

=head1 SYNOPSIS

Create state machine classes, also known as a FSA or a DFSA,
from a state machine description in Graph::Easy's graph description
language.

  use Graph::Easy::StateMachine;
  my $graph = Graph::Easy->new( <<FSA );
      [ BASE ] = EnterStateMachine =>
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
      -- whoops --> [FAIL] -- LeaveStateMachine --> [BASE]
  FSA
  eval $graph->as_FSA( base => 'SelectableURLfetcher')
      or die "FSA parser failure: $@";

Alternately, use the C<import> method to eval the FSA for you.

  paclage SelectableURLfetcher;
  use Graph::Easy::StateMachine <<FSA;
      [ BASE ] = EnterStateMachine =>
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
      -- whoops --> [FAIL] -- LeaveStateMachine --> [BASE]
  FSA


=head1 DESCRIPTION

This module adds a new layout engine to Graph::Easy.  The as_FSA layout
engine produces evaluatable perl code implementing the graph as a set
of namespaces each containing methods for all transitions to other states.

Absent a label on an edge from [A] to [B], state A's method to transition
to state B is called C<B>.

=head1 NODE NAMES

Node names represent states, labeled edges are aliases for the enter methods.

=head1 EDGE LABELS

In the example in the previous section, the
C<SelectableURLfetcher::disconnected::goodconnect> method reblesses
a C<SelectableURLfetcher::disconnected> object into the C<SelectableURLfetcher::inprogress>
package, while the C<SelectableURLfetcher::inprogress::goodconnect> method reblesses
an C<inprogress> object into the C<connected> state.  That is, states are represented
by packages, and transitioning occurs by reblessing the object.

=head1 ALL THIS MODULE DOES

single inheritance from the base class and transition methods
are all that gets defined.  You have to set up
your own convention for using them.  Something like

   for (@AsyncObjects) {
     $_->OnEntry();
     $_->${ $_->run ? \'HappyPath' : \'Problem' }()
   }

=head1 PARAMETERS TO THE as_FSA METHOD

C<as_FSA> takes named parameters that control the produced source code.

=head2 base

the C<base> parameter specifies the name space prefix
for the state machine class system.  When C<base> is not specified, the current
package is used.

=head2 BASESTATE

the C<BASESTATE> parameter reserves a state to indicate transitioning to the
base package. When not specified, the default is C<BASE>. While invalid transitions
will normally throw perl runtime "Can't locate object method" errors, attempts
to call invalid transition methods that are valid from the base state 
throw "invalid transition" errors.


=head1 Mickey Mouse

before adding the bit to as_FSA that enumerates all the methods that
can be used to transition from the base state into the state machine,
it would have been necessary to explicitly list all the entry methods
to prevent inheritance from allowing them in all states.


   package Acme::Bibbity::Bobbity::Boo;
   use Graph::Easy::StateMachine <<FSA;
      [BASE] - getwand -> [HAVEWAND] 
      [ PLAINDRELLA ] - domagic -> [FANCYDRELLA]
      - domagic -> [ATBALL]
      - midnight -> [REPUMPKINIZING]
      [BASE] - BeDrella -> [PLAINDRELLA]
      [PLAINDRELLA],[FANCYDRELLA] - getwand -> [ERROR]
      ...
   FSA

in version 0.03, transitions from BASE are noted and all states
get their own set of methods that throw errors if they haven't
got an entry method.  By entry method I mean a method that
transitions from BASE into a state class.  In the example above,
C<getwand> and C<BeDrella> are entry methods.

=head1 EXPORT

writes the C<as_FSA> method into L<Graph::Easy>'s name space.


=head1 HISTORY

=over 8

=item 0.01

Original version

=item 0.02

switched from C<enter_X> to the simpler C<X> for the default transition method name

=item 0.03

added invalid method error-throwers

=back


=head1 SEE ALSO

L<http://en.wikipedia.org/wiki/Finite_state_automata> for theory.
Also
L<http://en.wikipedia.org/wiki/Automata-based_programming> and
L<http://en.wikipedia.org/wiki/Event-driven_programming>

L<Graph::Easy> for how to create your graph

=head1 FEEDBACK AND SUPPORT

Please use L<http://rt.cpan.org> to report bugs and share patches

=head1 COPYRIGHT AND LICENSE

This tool is copyright (C) 2009 by David Nicol <davidnico@cpan.org>;
The FSA source code generated with it is copyrightable by whoever wrote the
graph.





