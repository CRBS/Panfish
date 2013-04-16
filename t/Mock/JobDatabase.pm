package Mock::JobDatabase;

use strict;
use English;
use warnings;


sub new {
   my $class = shift;
   my $self = {
     GetJobsByClusterAndState => undef,
     Update                   => undef
   };

   my $blessedself = bless($self,$class);
   return $blessedself;
}


=head3 addGetJobsByClusterAndStateResult

Sets expected value for getJobsByClusterAndState.
is set multiple times the values are pushed onto a stack and popped off in FIFO style

my $db->addGetJobsByClusterAndStateResult($cluster,\@jobs);

=cut

sub addGetJobsByClusterAndStateResult {
   my $self = shift;
   my $cluster = shift;
   my $state = shift;
   my $jobs = shift;
   
   push(@{$self->{GetJobsByClusterAndState}->{$cluster.$state}},$jobs);

}


=head3 getJobsByClusterAndState

Mock getJobsByClusterAndState returns whatever was set in addGetJobsByClusterAndState

=cut

sub getJobsByClusterAndState {
   my $self = shift;
   my $cluster = shift;
   my $state = shift;

   my $jobsRef = pop(@{$self->{GetJobsByClusterAndState}->{$cluster.$state}});
   if (!defined($jobsRef)){
     my @jobs = ();
     return @jobs;
   }

   return @{$jobsRef};
}

=head3 addUpdateResult

Sets return value when $job is passed to update() method.  The code internally
hashes jobs by getJobAndTaskId and if multiple are set with same they are pushed onto a queue

my $fu->addUpdateResult($job,$returnValue);

=cut

sub addUpdateResult {
   my $self = shift;
   my $job = shift;
   my $res = shift;

   push(@{$self->{Update}->{$job->getJobAndTaskId()}},$res);
}

sub update {
   my $self = shift;
   my $job = shift;
   return pop(@{$self->{Update}->{$job->getJobAndTaskId()}});
}


1;

__END__
