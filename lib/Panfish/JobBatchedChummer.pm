package Panfish::JobBatchedChummer;

use strict;
use English;
use warnings;

use Panfish::FileUtil;
use Panfish::PanfishConfig;
use Panfish::Logger;
use Panfish::FileJobDatabase;
use Panfish::JobState;
use Panfish::Job;
use Panfish::JobHashFactory;


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
     Config         => shift,
     JobDb          => shift,
     Logger         => shift,
     FileUtil       => shift,
     RemoteIO       => shift,
     JobHashFactory => shift,
     PathSorter     => shift
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
    if (!defined($self->{PathSorter})){
        return "Path Sorter not set";
    }
    my $res;
    
    # builds a hash where key is base dir where psub and commands
    # file reside and value is an array
    # of jobs with that have their psub job in that directory
    my $jobHashByPsubDir = $self->_buildJobHash($cluster); 

    $self->{Logger}->debug("Looking for jobs in ".Panfish::JobState->BATCHEDANDCHUMMED().
                           " state for $cluster");
    
    my $remoteBaseDir = $self->{Config}->getBaseDir($cluster);

    my @keys = keys %$jobHashByPsubDir;
    my @sortedJobPaths = $self->{PathSorter}->sort(\@keys);

    my $psubDir; 
    # iterate through each job array
    foreach $psubDir (@sortedJobPaths){
        
        $self->{Logger}->debug("Found ".@{$jobHashByPsubDir->{$psubDir}}.
                               " jobs with dir : $psubDir");

        if ($self->{Config}->isClusterPartOfThisCluster($cluster) == 0){
            $self->{Logger}->debug("Uploading $psubDir to $cluster");
              
            my $res = $self->{RemoteIO}->upload($psubDir,$cluster);
            if (defined($res)){
                 $self->{Logger}->error("Problem uploading $psubDir to $cluster : $res");
                 next;
            }
            $self->{Logger}->debug("Upload succeeded updating database");
        }
        else {
            $self->{Logger}->debug("No upload necessary updating database");
        }

        # need to update state
        for (my $x = 0; $x < @{$jobHashByPsubDir->{$psubDir}}; $x++){
            ${$jobHashByPsubDir->{$psubDir}}[$x]->setState(Panfish::JobState->BATCHEDANDCHUMMED());
            $res = $self->{JobDb}->update(${$jobHashByPsubDir->{$psubDir}}[$x]);
            if (defined($res)){
               $self->{Logger}->error("Unable to update job (".
                                      ${$jobHashByPsubDir->{$psubDir}}[$x]->getJobAndTaskId().") in database : $res");
            }
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
   
    if (!defined($self->{JobHashFactory})){
       $self->{Logger}->error("JobHashFactory is not defined");
    }
 
    my @jobs = $self->{JobDb}->getJobsByClusterAndState($cluster,
                Panfish::JobState->BATCHED());

    if (!@jobs){
            $self->{Logger}->debug("No jobs");
        return undef;
    }
    
    my ($jobHashByPsubDir,$error) = $self->{JobHashFactory}->getJobHash(\@jobs);

    return $jobHashByPsubDir;
}


1;

__END__


=head1 AUTHOR

Panfish::JobBatchedChummer is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut

