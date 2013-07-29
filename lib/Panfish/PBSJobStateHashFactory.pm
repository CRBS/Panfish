package Panfish::PBSJobStateHashFactory;

use strict;
use English;
use warnings;

use Panfish::PanfishConfig;
use Panfish::Logger;
use Panfish::JobState;
use Panfish::Job;

=head1 SYNOPSIS
   
  Panfish::PBSJobStateHashFactory -- Gets job states from PBS

=head1 DESCRIPTION

Using qstat, instances return a hash where the keys are job ids
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

Invokes qstat and builds a hash where the keys are job ids and
the value is a JobState object

=cut

sub getJobStateHash {
    my $self = shift;
    my %jobStatusHash = ();

    my $qstatCmd = $self->{Config}->getStat();

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
        if ($rows[$x]=~/^---.*/ ||
            $rows[$x]=~/^Job.*/){
           next;
        }
        
        $rows[$x]=~s/ +/ /g;
        @subSplit = split(" ",$rows[$x]);
        $realJobId = $subSplit[0];
        $realJobId=~s/\..*//;
        $rawState = $subSplit[4];
        $jobStatusHash{$realJobId}=$self->_convertStateToJobState($rawState);

    }
    return \%jobStatusHash;


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

Panfish::PBSJobStateHashFactory is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut

