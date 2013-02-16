package Panfish::Job;

use strict;
use English;
use warnings;

=head1 SYNOPSIS
   
  Panfish::Job -- Represents a Panfish job

=head1 DESCRIPTION

This object represents a Panfish Job.

=head1 METHODS

=head3 new

Creates new instance of Job object

my $job = Panfish::Job->new()

=cut

sub new {
   my $class = shift;
   my $self = {
     Queue             => shift,
     JobId             => shift,
     TaskId            => shift,
     JobName           => shift,
     CurrentWorkingDir => shift,
     Command           => shift,
     State          => shift
   };
   my $blessedself = bless($self,$class);
   return $blessedself;
}

=head3 getQueue 

=cut

sub getQueue {
   my $self = shift;
   return $self->{Queue};
}

=head3 getJobId

=cut

sub getJobId {
   my $self = shift;
   return $self->{JobId};
}

=head3 getTaskId

=cut

sub getTaskId {
   my $self = shift;
   return $self->{TaskId};
}


=head3 getCurrentWorkingDir

Gets the current working directory for the job

=cut

sub getCurrentWorkingDir {
   my $self = shift;
   return $self->{CurrentWorkingDir};
}

=head3 getJobName

Gets the Job Name

=cut

sub getJobName {
   my $self = shift;
   return $self->{JobName};
}

=head3 getCommand

Gets the Command to run

=cut

sub getCommand {
   my $self = shift;
   return $self->{Command};
}

=head3 getState

Gets state of the job

=cut

sub getState {
    my $self = shift;
    return $self->{State};
}

=head3 setState 

=cut

sub setState {
   my $self = shift;
   $self->{State} = shift;
}

1;

__END__


=head1 AUTHOR

Panfish::Job is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut

