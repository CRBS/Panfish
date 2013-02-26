package Panfish::JobState;

use strict;
use English;
use warnings;

=head1 SYNOPSIS
   
  Panfish::JobState -- Represents state of a Job

=head1 DESCRIPTION

Object represents an enumeration of job states.

=head1 METHODS


=head3 getAllStates 

Gets a list of all states except for KILL state and
returns them as an array.  Should probably just generate
this in the constructor....

=cut
sub getAllStates {
    my @stateArr;
    my $cnt = 0;
    $stateArr[$cnt++] = Panfish::JobState->SUBMITTED();
    $stateArr[$cnt++] = Panfish::JobState->QUEUED();
    $stateArr[$cnt++] = Panfish::JobState->BATCHED();
    $stateArr[$cnt++] = Panfish::JobState->BATCHEDANDCHUMMED();
    $stateArr[$cnt++] = Panfish::JobState->RUNNING();
    $stateArr[$cnt++] = Panfish::JobState->DONE();
    $stateArr[$cnt++] = Panfish::JobState->FAILED();
    return @stateArr;
}


=head3 SUBMITTED

Gets String representing submitted state

=cut

sub SUBMITTED {
   return "submitted";
}

=head3 QUEUED

Gets String representing queued state

=cut

sub QUEUED {
   return "queued";
}

=head3 BATCHED

Gets String representing batched state

=cut

sub BATCHED {
   return "batched";
}


=head3 BATCHEDNANDCHUMMED

Gets String representing batched and chummed state

=cut

sub BATCHEDANDCHUMMED {
   return "batchedandchummed";
}

=head3 RUNNING

Gets String representing running state

=cut

sub RUNNING {
   return "running";
}

=head3 DONE

Gets String representing done

=cut

sub DONE {
   return "done";
}

=head3 FAILED

Gets String representing failed

=cut

sub FAILED {
   my $self = shift;
   return "failed";
}

=head3 KILLED

Gets String representing kill

=cut

sub KILL {
   return "kill";
}



1;

__END__


=head1 AUTHOR

Panfish::JobState is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut

