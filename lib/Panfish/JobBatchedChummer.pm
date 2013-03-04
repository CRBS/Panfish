package Panfish::JobBatchedChummer;

use strict;
use English;
use warnings;

use Panfish::FileUtil;
use Panfish::PanfishConfig;
use Panfish::Logger;
use Panfish::JobDatabase;
use Panfish::JobState;
use Panfish::Job;

=head1 SYNOPSIS
   
  Panfish::JobBatchedChummer -- Sends batched commands and psub files to remote clusters

=head1 DESCRIPTION

Sends batched commands and psub files to remote clusters using rsync

=head1 METHODS

=head3 new

Creates new instance of Job object

my $job = PanfishJobBatchedChummer;

=cut

sub new {
   my $class = shift;
   my $self = {
     Config              => shift,
     JobDb               => shift,
     Logger              => shift,
     FileUtil            => shift,
     RsyncUploader       => shift,
   };
 
   if (!defined($self->{Logger})){
       $self->{Logger} = Panfish::Logger->new();
   }

   my $blessedself = bless($self,$class);
   return $blessedself;
}

=head3 chumBatchedJobs

This method looks for job files in batched state and extracts
the directory where the psub files reside  A unique list
is then created.  For each directory any CLUSTER sub directories
are uploaded to the remote cluster passed in.  Upon completion
any jobs that have been uploaded are set to batchedandchummed
state


my $res = $batcher->chumBatchedJobs($cluster);

=cut

sub chumBatchedJobs {
    my $self = shift;
    my $cluster = shift;

    if (!defined($cluster)){
        $self->{Logger}->error("Cluster is not set");
        return "Cluster is not set";
    }

    my $res;
    
    # builds a hash where key is base dir where psub and commands
    # file reside and value is an array
    # of jobs with that have their psub job in that directory
    my $jobHashByPsubDir = $self->_buildJobHash($cluster); 

    $self->{Logger}->debug("Looking for jobs in ".Panfish::JobState->BATCHEDANDCHUMMED().
                           " state for $cluster");
    my $remoteBaseDir = $self->{Config}->getClusterBaseDir($cluster);
 
    # iterate through each job array
    for my $psubDir (keys %$jobHashByPsubDir){
        
        $self->{Logger}->debug("Found ".@{$jobHashByPsubDir->{$psubDir}}.
                               " jobs with dir : $psubDir");

        $self->{Logger}->debug("Uploading $psubDir to $cluster");
              
        my $res = $self->{RsyncUploader}->upload($psubDir,$cluster);
        if (defined($res)){
             $self->{Logger}->error("Problem uploading $psubDir to $cluster : $res");
             next;
        }
        $self->{Logger}->debug("Upload succeeded updating database");
        #need to update state
        for (my $x = 0; $x < @{$jobHashByPsubDir->{$psubDir}}; $x++){
            ${$jobHashByPsubDir->{$psubDir}}[$x]->setState(Panfish::JobState->BATCHEDANDCHUMMED());
            $self->{JobDb}->update(${$jobHashByPsubDir->{$psubDir}}[$x]);
        } 
        $self->{Logger}->info("Chummed ".
                              @{$jobHashByPsubDir->{$psubDir}}.
                              " batched jobs on $cluster for path ".
                              $self->{FileUtil}->getDirname($psubDir)); 
    }
    return undef;
}


#
# Builds a hash of jobs where the key is
# the directory where the psub file resides 
# and the value in the hash is
# all job objects who share that same directory
# for their psub files
#
# Ex:
#   $hash{"/home/foo/blah"} => {Panfish::Job,Panfish::Job,Panfish::Job};
#
#
sub _buildJobHash {
    my $self = shift;
    my $cluster = shift;
    
    my @jobs = $self->{JobDb}->getJobsByClusterAndState($cluster,
                Panfish::JobState->BATCHED());

    if (!@jobs){
            $self->{Logger}->error("Error getting jobs from database");
        return undef;
    }
    my %jobHashByPsubDir = ();
    my $psubFile;
    my $jobCnt = 0;
    for (my $x = 0; $x < @jobs; $x++){
        if (defined($jobs[$x])){
            $psubFile = $jobs[$x]->getPsubFile();
            if (!defined($psubFile) || ! -f $psubFile){
                $self->{Logger}->error("Job $x missing psub file...");
                return undef;
            }
            push(@{$jobHashByPsubDir{$self->{FileUtil}->getDirname($psubFile)}},$jobs[$x]);
            $jobCnt++;
        }
    }

    if ($jobCnt > 0){
        $self->{Logger}->debug("Found $jobCnt job(s) that need to be chummed");
    }
    return \%jobHashByPsubDir;
}


1;

__END__


=head1 AUTHOR

Panfish::JobBatchedChummer is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut

