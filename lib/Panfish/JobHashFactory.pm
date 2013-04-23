package Panfish::JobHashFactory;

use strict;
use English;
use warnings;

use Panfish::Logger;
use Panfish::JobState;
use Panfish::Job;

=head1 SYNOPSIS
   
Panfish::JobHashFactory -- Creates hash of jobs using key generator passed in

=head1 DESCRIPTION

Given a set of jobs instances of this object create a hash of jobs
where the key is defined by the key generator and the value is
an array of jobs sharing that key value.

=head1 METHODS

=head3 new

Creates new instance of JobHashFactory object

=cut

sub new {
   my $class = shift;
   my $self = {
     KeyGenerator => shift,
     Logger       => shift
   };
 
   if (!defined($self->{Logger})){
       $self->{Logger} = Panfish::Logger->new();
   }

   my $blessedself = bless($self,$class);
   return $blessedself;
}

=head3 getJobHash 

Given an array of jobs this method creates a hash where the keys
are the psub files and the value is an array of jobs with that
psub file.

my $jobHash = $foo->getJobHash(\@jobs);

=cut

sub getJobHash {
    my $self = shift;
    my $jobs = shift;
    my %jobHash = ();

    if (!defined($self->{KeyGenerator})){
      $self->{Logger}->error("Key Generator not defined");
      return (undef,"Key Generator not defined");
    }

    if (!defined($jobs)){
       $self->{Logger}->error("Jobs array not defined");
       return (undef,"Jobs array not defined");
    }

    my $key;
 
    for (my $x = 0; $x < @{$jobs}; $x++){
        if (defined(${$jobs}[$x])){
            $key = $self->{KeyGenerator}->getKey(${$jobs}[$x]);
            if (defined($key)){
               push(@{$jobHash{$key}},${$jobs}[$x]);
            }
            else {
               $self->{Logger}->warn("Unable to get key from key generator for job ".${$jobs}[$x]->getJobAndTaskId());
            }
        }
        else {
           $self->{Logger}->debug("Job # $x in array is undefined");
        }
    }
    return (\%jobHash,undef);
}


1;

__END__


=head1 AUTHOR

Panfish::JobHashFactory is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut

