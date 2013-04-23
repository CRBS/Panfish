package Panfish::PsubHashKeyGenerator;

use strict;
use English;
use warnings;

=head1 SYNOPSIS
   
Panfish::PsubHashKeyGenerator -- Generates Psub hash key from job

=head1 DESCRIPTION

This object examines a Job and returns the psub file with path to be used
as hash key

=head1 METHODS

=head3 new

Creates new instance of PsubHashKeyGenerator

my $keygen = Panfish::PsubHashKeyGenerator->new($logger,Panfish::FileUtil->new());

=cut

sub new {
   my $class = shift;
   my $self = {
     Logger    => shift,
     FileUtil  => shift
   };
   my $blessedself = bless($self,$class);
   return $blessedself;
}

=head3 getKey

Given a valid job this method returns the psub file
as the key for the job with the following caveat:  The psub file
must exist on the filesystem as detected by calling runFileTest("-f",$path) using
FileUtil.  Otherwise undef is returned.

my $key = $keyGen->getKey($job);

=cut

sub getKey {
   my $self = shift;
   my $job = shift;

   if (!defined($job)){
      $self->{Logger}->error("Job is not defined");
      return undef;
   }

   if (!defined($self->{FileUtil})){
      $self->{Logger}->error("FileUtil is not defined");
      return undef;
   }

   my $psubFile = $job->getPsubFile();

   if (!defined($psubFile)){
      $self->{Logger}->debug("psub file is not defined for job ".$job->getJobAndTaskId());
      return undef;
   }
   if (! $self->{FileUtil}->runFileTest("-f",$psubFile)){
      $self->{Logger}->error("psub file ".$psubFile." missing for job ".$job->getJobAndTaskId());
      return undef;
   }
   
   return $psubFile;
}

1;

__END__


=head1 AUTHOR

Panfish::PsubHashKeyGenerator is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut

