package Panfish::CurrentWorkingDirHashKeyGenerator;

use strict;
use English;
use warnings;

=head1 SYNOPSIS
   
Panfish::CurrentWorkingDirHashKeyGenerator -- Generates Current working directory hash key from job

=head1 DESCRIPTION

This object examines a Job and returns the current working directory to be used
as a hash key.

=head1 METHODS

=head3 new

Creates new instance of CurrentWorkingDirHashKeyGenerator

my $job = Panfish::Job->new()

=cut

sub new {
   my $class = shift;
   my $self = {
     Logger           => shift
   };
   my $blessedself = bless($self,$class);
   return $blessedself;
}

=head3 getKey

Given a valid job this method returns the current working directory
as the key for the job or undef if there was a problem.

my $key = $keyGen->getKey($job);

=cut

sub getKey {
   my $self = shift;
   my $job = shift;

   if (!defined($job)){
      $self->{Logger}->error("Job is not defined");
      return undef;
   }
   return $job->getCurrentWorkingDir();
}

1;

__END__


=head1 AUTHOR

Panfish::CurrentWorkingDirHashKeyGenerator is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut

