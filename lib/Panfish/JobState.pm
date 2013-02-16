package Panfish::JobState;

use strict;
use English;
use warnings;

=head1 SYNOPSIS
   
  Panfish::JobState -- Represents state of a Job

=head1 DESCRIPTION

This object represents state of a Job.

=head1 METHODS

=head3 new

Creates new instance of Job object

my $job = Panfish::Job->new()

=cut

sub new {
   my $class = shift;
   my $self = {
     SUBMITTED         => "submitted",
     QUEUED            => "queued",
     BATCHED           => "batched",
     BATCHEDANDCHUMMED => "batchedandchummed",
     RUNNING           => "running",
     DONE              => "done",
     FAILED            => "failed"
   };


   my $blessedself = bless($self,$class);
   return $blessedself;
}

=head3 SUBMITTED

Gets String representing submitted state

=cut

sub SUBMITTED {
   my $self = shift;
   return $self->{SUBMITTED};
}

=head3 QUEUED

Gets String representing queued state

=cut

sub QUEUED {
   my $self = shift;
   return $self->{QUEUED};
}

=head3 BATCHED

Gets String representing batched state

=cut

sub BATCHED {
   my $self = shift;
   return $self->{BATCHED};
}


=head3 BATCHEDNANDCHUMMED

Gets String representing batched and chummed state

=cut

sub BATCHEDANDCHUMMED {
   my $self = shift;
   return $self->{BATCHEDANDCHUMMED};
}

=head3 RUNNING

Gets String representing running state

=cut

sub RUNNING {
   my $self = shift;
   return $self->{RUNNING};
}

=head3 DONE

Gets String representing done

=cut

sub DONE {
   my $self = shift;
   return $self->{DONE};
}

=head3 FAILED

Gets String representing failed

=cut

sub FAILED {
   my $self = shift;
   return $self->{FAILED};
}

1;

__END__


=head1 AUTHOR

Panfish::JobState is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut

