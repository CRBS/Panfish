package Panfish::PsubIdHashKeyGenerator;

use strict;
use English;
use warnings;

=head1 SYNOPSIS
   
Panfish::PsubIdHashKeyGenerator -- Generates Psub id hash key from job

=head1 DESCRIPTION

This object examines a Job and returns the psub id  to be used
as hash key.  The psub id is the numeric value within the filename of the
psub file.

=head1 METHODS

=head3 new

Creates new instance of PsubIdHashKeyGenerator

my $keygen = Panfish::PsubIdHashKeyGenerator->new(PsubHashKeyGenerator->new(...),$logger);

=cut

sub new {
   my $class = shift;
   my $self = {
     Logger  => shift,
     KeyGen  => shift
   };
   my $blessedself = bless($self,$class);
   return $blessedself;
}

=head3 getKey

Given a valid job this method returns the psub id
as the key for the job.  The method uses PsubHashKeyGenerator object
to get the psub file and then extracts the id from that path

my $key = $keyGen->getKey($job);

=cut

sub getKey {
   my $self = shift;
   my $job = shift;

   if (!defined($job)){
      $self->{Logger}->error("Job is not defined");
      return undef;
   }

   if (!defined($self->{KeyGen})){
      $self->{Logger}->error("PsubHashKeyGenerator is not defined");
      return undef;
   }

   my $psubFile = $self->{KeyGen}->getKey($job);

   if (!defined($psubFile)){
      $self->{Logger}->debug("psub file is not defined for job ".$job->getJobAndTaskId());
      return undef;
   }

   $psubFile=~s/^.*\///;
   $psubFile=~s/\.psub//;
   
   return $psubFile;
}

1;

__END__


=head1 AUTHOR

Panfish::PsubIdHashKeyGenerator is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut

