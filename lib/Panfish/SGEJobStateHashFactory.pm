package Panfish::SGEJobStateHashFactory;

use strict;
use English;
use warnings;

use Panfish::PanfishConfig;
use Panfish::Logger;
use Panfish::JobState;
use Panfish::Job;

=head1 SYNOPSIS
   
  Panfish::SGEJobStateHashFactory -- Obtains status of SGE jobs using qstat

=head1 DESCRIPTION

Obtains a hash of job states by invoking SGE qstat command and
building a hash where the key is the job id and the value is
a JobState object

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

Calls qstat to get current status of all jobs 
The code then uses that result to build a hash
of statuses for each job.

=cut

sub getJobStateHash {
    my $self = shift;
    my %jobStatusHash = ();
   
    my $qstatCmd = $self->{Config}->getQstat()." -u \"*\" 2>&1";


    $self->{Logger}->debug("Running $qstatCmd");    
    my $exit = $self->{Executor}->executeCommand($qstatCmd,60);
    if ($exit != 0){
       $self->{Logger}->error("Unable to run ".$self->{Executor}->getCommand().
                               "  : ".$self->{Executor}->getOutput());
       return (\%jobStatusHash,"Error running qstat");
    }


    my $realJobId;
    my $rawState;
    my @subSplit;
    my @rows = split("\n",$self->{Executor}->getOutput());
    for (my $x = 0; $x < @rows; $x++){
 
        chomp($rows[$x]);
        if ($rows[$x]=~/^---.*/ ||
            $rows[$x]=~/^job.*/){
           next;
        }
        $rows[$x]=~s/^ *//;
        $rows[$x]=~s/ +/ /g;
        @subSplit = split(" ",$rows[$x]);
        # $self->{Logger}->debug("XXXXXXX".$rows[$x]);
        #for (my $y = 0; $y < @subSplit; $y++){
        #   $self->{Logger}->debug("YYY $y - $subSplit[$y]");
        #} 
        $realJobId = $subSplit[0];
        $rawState = $subSplit[4];
        if (!defined($jobStatusHash{$realJobId})){
           $self->{Logger}->debug("Setting hash ".$realJobId." => ($rawState) -> ".$self->_convertStateToJobState($rawState));
           $jobStatusHash{$realJobId}=$self->_convertStateToJobState($rawState);
        }
        
    }
    return (\%jobStatusHash,undef);
}


sub _convertStateToJobState {
   my $self = shift;
   my $rawState = shift;

   if ($rawState eq "r" ||
       $rawState eq "hr" ||
       $rawState eq "dr" ||
       $rawState eq "R"){
      return Panfish::JobState->RUNNING();
   }

   if ($rawState eq "Eqw" ||
       $rawState eq "E"){
      return Panfish::JobState->FAILED();
   }

   if ($rawState eq "hqw" ||
       $rawState eq "S" ||
       $rawState eq "qw" ||
       $rawState eq "Q"  ||
       $rawState eq "H"){
      return Panfish::JobState->QUEUED();
   }
   if ($rawState eq "C"){
      return Panfish::JobState->DONE();
   }

   return Panfish::JobState->UNKNOWN();
}

1;

__END__


=head1 AUTHOR

Panfish::SGEJobStateHashFactory is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut

