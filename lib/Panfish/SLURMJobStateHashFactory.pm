package Panfish::SLURMJobStateHashFactory;

use strict;
use English;
use warnings;

use Panfish::PanfishConfig;
use Panfish::Logger;
use Panfish::JobState;
use Panfish::Job;

=head1 SYNOPSIS
   
  Panfish::SLURMJobStateHashFactory -- Gets job states from SLURM

=head1 DESCRIPTION

Using squeue, instances return a hash where the keys are job ids
and the values are JobState objects. 

=head1 METHODS

=head3 new

Creates new instance of Job object

=cut

sub new {
   my $class = shift;
   my $self = {
     Config       => shift,
     Logger       => shift,
     Executor  => shift,
   };
 
   if (!defined($self->{Logger})){
       $self->{Logger} = Panfish::Logger->new();
   }

   my $blessedself = bless($self,$class);
   return $blessedself;
}

=head3 getJobStateHash

Invokes squeue and builds a hash where the keys are job ids and
the value is a JobState object

=cut

sub getJobStateHash {
    my $self = shift;
    my %jobStatusHash = ();

    my $qstatCmd = $self->{Config}->getQstat()." 2>&1";

    $self->{Logger}->debug("Running $qstatCmd");
    my $exit = $self->{Executor}->executeCommand($qstatCmd,60);
    if ($exit != 0){
       $self->{Logger}->error("Unable to run ".$self->{Executor}->getCommand().
                               "  : ".$self->{Executor}->getOutput());
       return \%jobStatusHash;
    }

    my $realJobId;
    my $rawState;
    my @subSplit;
    my @rows = split("\n",$self->{Executor}->getOutput());
    for (my $x = 0; $x < @rows; $x++){

        chomp($rows[$x]);
        if ($rows[$x]=~/^ *JOBID*/){
           next;
        }
        
        $rows[$x]=~s/ +/ /g;
        @subSplit = split(" ",$rows[$x]);
        $realJobId = $subSplit[0];
        $rawState = $subSplit[4];
        if (!defined($jobStatusHash{$realJobId})){
            $self->{Logger}->debug("Setting hash ".$realJobId." => ($rawState) -> ".$self->_convertStateToJobState($rawState));
            $jobStatusHash{$realJobId}=$self->_convertStateToJobState($rawState);
        }            
    }
    return \%jobStatusHash;


}


sub _convertStateToJobState {
   my $self = shift;
   my $rawState = shift;

   if ($rawState eq "R" ||
       $rawState eq "CF"||
       $rawState eq "CG"){
      return Panfish::JobState->RUNNING();
   }

   if ($rawState eq "F" ||
       $rawState eq "NF" ||
       $rawState eq "PR" ||
       $rawState eq "TO"){
      return Panfish::JobState->FAILED();
   }

   if ($rawState eq "PD" ||
       $rawState eq "S"){
      return Panfish::JobState->QUEUED();
   }
   if ($rawState eq "CA" ||
       $rawState eq "CD"){
      return Panfish::JobState->DONE();
   }

   return Panfish::JobState->UNKNOWN();
}


1;

__END__


=head1 AUTHOR

Panfish::SLURMJobStateHashFactory is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut

