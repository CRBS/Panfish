package Panfish::PsubDirnameHashKeyGenerator;

use strict;
use English;
use warnings;

=head1 SYNOPSIS
   
Panfish::PsubDirnameHashKeyGenerator -- Generates dirname of psub file  hash key from job

=head1 DESCRIPTION

This object examines a Job and returns the directory where the psub file resides
as a hash key. 

=head1 METHODS

=head3 new

Creates new instance of PsubDirnameHashKeyGenerator

my $keygen = Panfish::PsubDirnameHashKeyGenerator->new($logger,PsubHashKeyGenerator->new(...),Panfish::FileUtile->new());

=cut

sub new {
   my $class = shift;
   my $self = {
     Logger   => shift,
     KeyGen   => shift,
     FileUtil => shift
   };
   my $blessedself = bless($self,$class);
   return $blessedself;
}

=head3 getKey

Given a valid job this method returns the dirname of psub file
as the key for the job.  The method uses PsubHashKeyGenerator object
to get the psub file and then extracts the dirname from that path

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

   if (!defined($self->{FileUtil})){
      $self->{Logger}->error("FileUtil is not defined");
      return undef;
   }

   my $psubFile = $self->{KeyGen}->getKey($job);

   if (!defined($psubFile)){
      $self->{Logger}->debug("psub file is not defined for job ".$job->getJobAndTaskId());
      return undef;
   }

   return $self->{FileUtil}->getDirname($psubFile);
}

1;

__END__


=head1 AUTHOR

Panfish::PsubDirnameHashKeyGenerator is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut

