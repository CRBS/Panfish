package Panfish::FileJobDatabase;

use strict;
use English;
use warnings;


use Panfish::FileUtil;
use Panfish::Logger;
use Panfish::ConfigFromFileFactory;
use Panfish::Config;
use Panfish::JobState;
use Panfish::Job;
=head1 SYNOPSIS
   
  Panfish::FileJobDatabase -- Database to store Jobs utilizing the filesystem

=head1 DESCRIPTION

Database for Jobs using files in the filesystem as the storage
medium.

=head1 METHODS

=head3 new

Creates new instance of FileJobDatabase

my $logger = Panfish::Logger->new();
my $readerWriter =  Panfish::FileReaderWriterImpl->new($logger);

my $jobDb = Panfish::FileJobDatabase->new($readerWriter,"/home/foo",$logger);

=cut

sub new {
   my $class = shift;
   my $self = {
     FileReaderWriter  => shift,
     SubmitDir         => shift,
     FileUtil          => shift,
     Logger            => shift,
     ConfigFactory     => undef,
     UNASSIGNED_CLUSTER => "unassigned",
     JOB_NAME_KEY      => "job.name",
     COMMAND_KEY       => "command.to.run",
     CURRENT_DIR_KEY   => "current.working.dir",
     COMMANDS_FILE_KEY => "commands.file",
     PSUB_FILE_KEY     => "psub.file",
     REAL_JOB_ID_KEY   => "real.job.id",
     FAIL_REASON_KEY   => "fail.reason",
     BATCH_FACTOR_KEY  => "batch.factor",
     WALLTIME_KEY      => "walltime",
     ACCOUNT_KEY       => "account",
     RAW_WRITE_OUTPUT_LOCAL_KEY => "raw.write.output.local",
     RAW_COMMAND_KEY        => "raw.command",
     RAW_OUT_PATH_KEY       => "raw.out.path",
     RAW_ERROR_PATH_KEY     => "raw.error.path",
     RAW_WALLTIME_KEY       => "raw.walltime",
     RAW_BATCH_FACTOR_KEY   => "raw.batch.factor",
     RAW_ACCOUNT_KEY         => "raw.account",
     
   };

   if (!defined($self->{FileReaderWriter})){
        print STDERR "file reader writer not set";
        return undef;
   }
   if (!defined($self->{SubmitDir})){
       print STDERR "submitdir not set";
       return undef;
   }
   if (!defined($self->{FileUtil})){
       print STDERR "fileutil not set";
       return undef;
   }
   if (!defined($self->{Logger})){
       print STDERR "logger not set";
        return undef;
   }
   $self->{ConfigFactory} = Panfish::ConfigFromFileFactory->new($self->{FileReaderWriter},$self->{Logger});
   my $blessedself = bless($self,$class);
   return $blessedself;
}

=head3 initializeDatabase

This method will create the necessary directories under
the submit directory, which will be created if it does not
exist. Success will return a 1 otherwise 0 will be returned

=cut

sub initializeDatabase {
    my $self = shift;
    my $cluster = shift; 
    if (! -d $self->{SubmitDir}){
       if ($self->{FileUtil}->makeDir($self->{SubmitDir}) != 1){ 
           $self->{Logger}->error("Unable to create ".$self->{SubmitDir}." directory");
           return 0;
       }
    }
    if (! -d $self->{SubmitDir}."/".$cluster){
       if ($self->{FileUtil}->makeDir($self->{SubmitDir}."/".$cluster) != 1){
           $self->{Logger}->error("Unable to create ".$self->{SubmitDir}."/".$cluster." directory");
           return 0;
       }
    }


    my @jStates = Panfish::JobState->getAllStates();

    # gotta add KILL cause its not really a state
    push (@jStates,Panfish::JobState->KILL());

    for (my $x = 0; $x < @jStates; $x++){
      my $statedir = $self->{SubmitDir}."/".$cluster."/".$jStates[$x];
      if (! -d $statedir){
         if ($self->{FileUtil}->makeDir($statedir) != 1){
             $self->{Logger}->error("Unable to create ".$statedir." directory");
             return 0;
         }
      }
    }

    return 1;
}

sub _createClusterDir {
    my $self = shift;
    my $cluster = shift;
    if (! -d $self->{SubmitDir}){
       if ($self->{FileUtil}->makeDir($self->{SubmitDir}) != 1){
           $self->{Logger}->error("Unable to create ".$self->{SubmitDir}." directory");
           return 0;
       }
    }
    my $clusterdir = $self->{SubmitDir}."/".$cluster;
    if (! -d $clusterdir){
       if ($self->{FileUtil}->makeDir($clusterdir) != 1){
           $self->{Logger}->error("Unable to create ".$clusterdir." directory");
           return 0;
       }
    }
    return 1;
}

sub initializeUnassignedDatabase {
    my $self = shift;
    my $cluster = "unassigned";
    if ($self->_createClusterDir($cluster) == 0){
       return 0;
    }
    my $submitdir = $self->{SubmitDir}."/".$cluster."/".Panfish::JobState->SUBMITTED();
    if (! -d $submitdir){
       if ($self->{FileUtil}->makeDir($submitdir) != 1){
             $self->{Logger}->error("Unable to create ".$submitdir." directory");
             return 0;
         }
    }
    return 1;
}


=head3 getSummaryForCluster

This method returns a human readable string summarizing
The number of jobs in each state for a given cluster

Format of output:

(#) submitted (#) queued (#) batched (#) batchedandchummed (#) running (#) done (#) failed

=cut

sub getSummaryForCluster {
    my $self = shift;
    my $cluster = shift;

    
    # basically get # of files in each directory and report it
    # in a string
    my $outStr = "";

    my $summaryHashRef = $self->getHashtableSummaryForCluster($cluster);
 
    my @states = Panfish::JobState->getAllStates();
    for (my $x = 0; $x < @states; $x++){
        $outStr .= " (".$summaryHashRef->{$states[$x]}.") $states[$x]";
    }
    
    return $outStr;
}

=head3 getHashtableSummaryForCluster

This method builds a hashtable containing counts of jobs in all states for a 
given cluster.  The hashtable's key is the state and the value is the number
of jobs in that state.  The hashtable is returned as a reference and
should be accessed like so:

my $hTable = $db->getHashtableSummaryForCluster($cluster);

print $hTable->{Panfish::JobState->RUNNING()}." jobs in state ".Panfish::JobState->RUNNING()." on cluster $cluster\n";

=cut

sub getHashtableSummaryForCluster {
    my $self = shift;
    my $cluster = shift;
    my %summaryHash = ();
    # basically get # of files in each directory and report it
    #     # in a string
    my $outStr = "";
    my @states = Panfish::JobState->getAllStates();
    my $count = 0;
    for (my $x = 0; $x < @states; $x++){
        $count = $self->{FileUtil}->getNumberFilesInDirectory($self->{SubmitDir}.
                                                              "/".$cluster.
                                                              "/".$states[$x]);
        $summaryHash{$states[$x]} = $count;
    }

    return \%summaryHash;
}

=head3 insert

Adds a new job to the database returning undef upon success otherwise
a string with the error upon failure.

$jobDb->insert($job);

=cut

sub insert {
   my $self = shift;
   my $job = shift;
   my $skipCheck = shift;

   if (!defined($job)){
     return "Job passed in is undefined";
   }

   if (!defined($job->getCluster())){
      return "Job does not have a cluster";
   }
   if (!defined($job->getState())){
      return "Job does not have a state";
   }
   if (!defined($job->getJobId())){
      return "Job id not set";
   }

   # to be safe check that this job isn't already in db
   if (!defined($skipCheck)){
      my $existingJob = $self->getJobByClusterAndId($job->getCluster(),
                                              $job->getJobId(),
                                              $job->getTaskId());
      if (defined($existingJob)){
         return "Job ".$job->getJobAndTaskId()." already exists in database in state ".$existingJob->getState().
                " unable to insert";
      }
   }


   my $outFile = $self->{SubmitDir}."/".$job->getCluster()."/".
                 $job->getState()."/".
                 $job->getJobId().$self->_getTaskSuffix($job->getTaskId());

   if (defined($self->{Logger})){
     $self->{Logger}->debug("Attempting to insert job by writing to file: $outFile");
   }


   my $res = $self->{FileReaderWriter}->openFile(">$outFile");
   if (defined($res)){
     return $res;
   }

   if (defined($job->getCurrentWorkingDir())){
      $self->{FileReaderWriter}->write($self->{CURRENT_DIR_KEY}."=".$job->getCurrentWorkingDir()."\n");
   }

   if (defined($job->getJobName())){
       $self->{FileReaderWriter}->write($self->{JOB_NAME_KEY}."=".$job->getJobName()."\n");
   }
   
   if (defined($job->getCommand())){
     $self->{FileReaderWriter}->write($self->{COMMAND_KEY}."=".$job->getCommand()."\n");
   }

   if (defined($job->getCommandsFile())){
       $self->{FileReaderWriter}->write($self->{COMMANDS_FILE_KEY}."=".$job->getCommandsFile()."\n");
   }

   if (defined($job->getPsubFile())){
       $self->{FileReaderWriter}->write($self->{PSUB_FILE_KEY}."=".$job->getPsubFile()."\n");
   }

   if (defined($job->getRealJobId())){
       $self->{FileReaderWriter}->write($self->{REAL_JOB_ID_KEY}."=".$job->getRealJobId()."\n");
   }

   if (defined($job->getFailReason())){
      $self->{FileReaderWriter}->write($self->{FAIL_REASON_KEY}."=".$job->getFailReason()."\n");
   }

   if (defined($job->getBatchFactor())){
      $self->{FileReaderWriter}->write($self->{BATCH_FACTOR_KEY}."=".$job->getBatchFactor()."\n");
   }

   if (defined($job->getWallTime())){
      $self->{FileReaderWriter}->write($self->{WALLTIME_KEY}."=".$job->getWallTime()."\n");
   }

   if (defined($job->getAccount())){
      $self->{FileReaderWriter}->write($self->{ACCOUNT_KEY}."=".$job->getAccount()."\n");
   }
   
   if (defined($job->getRawWriteOutputLocal())){
      $self->{FileReaderWriter}->write($self->{RAW_WRITE_OUTPUT_LOCAL_KEY}."=".$job->getRawWriteOutputLocal()."\n");
   }
  
   if (defined($job->getRawCommand())){
      $self->{FileReaderWriter}->write($self->{RAW_COMMAND_KEY}."=".$job->getRawCommand()."\n");
   }

   if (defined($job->getRawOutPath())){
      $self->{FileReaderWriter}->write($self->{RAW_OUT_PATH_KEY}."=".$job->getRawOutPath()."\n");
   }

   if (defined($job->getRawErrorPath())){
      $self->{FileReaderWriter}->write($self->{RAW_ERROR_PATH_KEY}."=".$job->getRawErrorPath()."\n");
   }

   if (defined($job->getRawWalltime())){
      $self->{FileReaderWriter}->write($self->{RAW_WALLTIME_KEY}."=".$job->getRawWalltime()."\n");
   }

   if (defined($job->getRawBatchfactor())){
      $self->{FileReaderWriter}->write($self->{RAW_BATCH_FACTOR_KEY}."=".$job->getRawBatchfactor()."\n");
   }

   if (defined($job->getRawAccount())){
      $self->{FileReaderWriter}->write($self->{RAW_ACCOUNT_KEY}."=".$job->getRawAccount()."\n");
   }

   $self->{FileReaderWriter}->close();

   return undef;
}



#
# Internal method that creates taskSuffix
# which is .# if the taskid is set otherwise
# an empty string is returned
#
sub _getTaskSuffix {
    my $self = shift;
    my $taskId = shift;
    my $taskSuffix = "";

   #only append task id if its set
   if (defined($taskId) &&
       $taskId ne ""){
       $taskSuffix = ".".$taskId;
   }
   return $taskSuffix;
}


=head3 update

Updates the job in the database

=cut

sub update {
   my $self = shift;
   my $job = shift;
   
   if (!defined($job)){
      return "job is undef";
   }

   # find job in system
   my $oldJob = $self->getJobByClusterAndId($job->getCluster(),$job->getJobId(),$job->getTaskId());
   my $res;
   if (defined($oldJob)){
   
      # is the new job different? if no return
      if ($job->equals($oldJob) == 1){
         $self->{Logger}->debug("Jobs match");
         return undef;
      }
   
      $self->{Logger}->debug("Deleting old job: ".$oldJob->getJobAndTaskId());
      # delete that job
      $res =$self->delete($oldJob);

      if (defined($res)){
         $self->{Logger}->error("Unable to delete old job $res");
         return "Unable to delete old job $res";
      }
   }

   # write out new job, the second argument tells insert not to recheck
   return $self->insert($job,1);
}

sub updateArray {
   my $self = shift;
   my $jobArrayRef = shift;

   $self->{Logger}->info(" found ".@{$jobArrayRef}." to update");

   if (!defined($jobArrayRef) || @{$jobArrayRef} <= 0){
      $self->{Logger}->error("No jobs to update");
      return "no jobs to update";
   }
   my $res;
   for (my $x = 0; $x < @{$jobArrayRef}; $x++){
     $self->{Logger}->info("Updating ".${$jobArrayRef}[$x]->getJobId().
                           ".".${$jobArrayRef}[$x]->getTaskId()); 
     $res = $self->update(${$jobArrayRef}[$x]);
     if (defined($res)){
         return $res;
     }
     
   }

   return undef;
}

=head3 getJobStatesByCluster

Generates a hash of jobids to states for a given cluster.
my $stateHash = $jobDb->getJobStatesByCluster("gordon_shadow.q");

# state hash will have the following:
# JOBID.TASKID => STATE
#

=cut

sub getJobStatesByCluster {
  my $self = shift;
  my $cluster = shift;
  my %jobStateHash = ();
  my $searchDir;
  my $jobId;

  my @states = Panfish::JobState->getAllStates();
  for (my $x = 0; $x < @states; $x++){
    $searchDir = $self->{SubmitDir}."/".$cluster."/".$states[$x];
   
    my @files = $self->{FileUtil}->getFilesInDirectory($searchDir);
    if (!@files){
      next;
    }
    for (my $y = 0; $y < @files; $y++){
      if (!defined($files[$y])){
        next;
      }
      $jobId = $files[$y];
      $jobId=~s/^.*\///;
      $jobStateHash{$jobId} = $states[$x];
    }
  }
 
  return \%jobStateHash;
}


=head3 getJobsByClusterAndState

Gets array of jobs from database filtering by cluster and state.  If
there was an error undef is returned otherwise an empty array.

my @job = $jobDb->getJobByClusterAndState("gordon_shadow.q",$state->SUBMITTED());

=cut

sub getJobsByClusterAndState {
    my $self = shift;
    my $cluster = shift;
    my $state = shift;
    my @jobArr;
    my $searchDir = $self->{SubmitDir}."/".$cluster."/".$state;
    
    my @files = $self->{FileUtil}->getFilesInDirectory($searchDir);
    if (!@files){
       return @jobArr;
    }
    my $len = @files;

    if (defined($self->{Logger})){
        $self->{Logger}->debug("Found $len files in search of $searchDir");
    }

    my $curJob;
    for (my $x = 0; $x < @files; $x++){
       $curJob = $self->_getJobFromJobFile($files[$x],$cluster,$state);
       if (!defined($curJob)){
           if (defined($self->{Logger})){
               $self->{Logger}->error("Problem creating job from $files[$x]");
           }
           return undef;
       }
       push(@jobArr,$curJob);
    }
    return @jobArr;
}

=head3 getNumberOfJobsInState

Gets the number of jobs in the state specified

=cut

sub getNumberOfJobsInState {
    my $self = shift;
    my $cluster = shift;
    my $state = shift;

    my $searchDir = $self->{SubmitDir}."/".$cluster."/".$state;

    $self->{Logger}->debug("Searching $searchDir");

    my @files = $self->{FileUtil}->getFilesInDirectory($searchDir);
    if (!@files){
       $self->{Logger}->debug("Did not find any jobs in state $state on cluster $cluster");
       return 0;
    }
    my $len = @files;
    return $len;
}

=head3 getJobByClusterAndId

Gets a job from the database if any exist.  This is done
by searching the submit directory (set in the constructor) for
any files matching $JOBID.$TASKID.  When found the job object is
constructed by reading the contents of the file and looking at
which sub directory the file resides in.  This sub directory denotes
the state of the job.

my $job = $jobDb->getJobByClusterAndId("gordon_shadow.q","123",1");


=cut

sub getJobByClusterAndId {
   my $self = shift;
   my $cluster = shift;
   my $jobId = shift;
   my $taskId = shift;


   my $jobFileName = "$jobId".$self->_getTaskSuffix($taskId);
   my $searchDir = $self->{SubmitDir}."/".$cluster;
   if (defined($self->{Logger})){
      $self->{Logger}->debug("Looking for job: $jobFileName under $searchDir");
   } 

   my ($state,$jobFile) = $self->_findJobFile($searchDir,$jobFileName);

   if (!defined($jobFile)){
     return undef;
   }

   return $self->_getJobFromJobFile($jobFile,$cluster);
}

sub _findJobFile {
   my $self = shift;
   my $prefixDir = shift;
   my $fileName = shift;
   
   my @jobStates = Panfish::JobState->getAllStates();
   for (my $x = 0; $x < @jobStates; $x++){
      if ($self->{FileUtil}->runFileTest("-e",$prefixDir."/".$jobStates[$x]."/".$fileName)){
         return ($jobStates[$x],$prefixDir."/".$jobStates[$x]."/".$fileName);
      }
   }
   return undef,undef;
}

=head3 getJobStateByClusterAndId

Given cluster, job id/task return current state of job

my $db->getJobStateByClusterAndId($cluster,$jobId,$taskId);

=cut

sub getJobStateByClusterAndId {
    my $self = shift;
    my $cluster = shift;
    my $jobId = shift;
    my $taskId = shift;
 
    if (!defined($jobId)){
       $self->{Logger}->error("Job Id not defined");
       return Panfish::JobState->UNKNOWN();
    }

    if (!defined($cluster)){
       $self->{Logger}->error("Cluster Id not defined");
       return Panfish::JobState->UNKNOWN();
    }
 
    my $jobFileName = "$jobId".$self->_getTaskSuffix($taskId);
    my $searchDir = $self->{SubmitDir}."/".$cluster;
    $self->{Logger}->debug("Looking for job: $jobFileName under $searchDir");
    my ($state,$jobFile) = $self->_findJobFile($searchDir,$jobFileName);
   
    # if we couldnt find the job just return unknown for the state
    if (!defined($state)){
        $self->{Logger}->warn("Unable to find job: $jobFileName under $searchDir");
        return Panfish::JobState->UNKNOWN();
    }

    return $state;
}


=head3 getJobByClusterAndStateAndId

Given cluster, state, and job id/task return the job.  
In some implementations knowing the state will speed
up the search.

=cut

sub getJobByClusterAndStateAndId {
    my $self = shift;
    my $cluster = shift;
    my $state = shift;
    my $jobId = shift;
    my $taskId = shift;


    my $jobFileName = "$jobId".$self->_getTaskSuffix($taskId);
    my $searchDir = $self->{SubmitDir}."/".$cluster."/".$state;
    if (defined($self->{Logger})){
       $self->{Logger}->debug("Looking for job: $jobFileName under $searchDir");
    }

    my $jobFile = $self->_findJobFile($searchDir,$jobFileName);
    if (!defined($jobFile)){
       return undef;
    }

    return $self->_getJobFromJobFile($jobFile,$cluster);
}


#
# Gets a job object from a job file
#
sub _getJobFromJobFile {
    my $self = shift;
    my $jobFile = shift;
    my $cluster = shift;
    my $state = shift;
    my $jobId = undef;
    my $taskId = undef;


    my $config = $self->{ConfigFactory}->getConfig($jobFile);
    if (!defined($config)){
        if (defined($self->{Logger})){
            $self->{Logger}->error("Unable to load config for file $jobFile");
        }
        return undef;
    }
    my $jFileName = $jobFile;
    $jFileName=~s/^.*\///;
    $jobId = $jFileName;
 
    if ($jFileName=~/^.*\/(.+)\.([0-9]+)$/){
       $jobId = $1;
       $taskId = $2;
    }

    if (!defined($state)){
        $state = $jobFile;
        $state =~s/^$self->{SubmitDir}\/$cluster\///;

        $state =~s/\/.*$//;
    }

       
   $self->{Logger}->debug("Job $jobId".
                          $self->_getTaskSuffix($taskId).
                          " in cluster $cluster in state $state");

   return Panfish::Job->new($cluster,$jobId,$taskId,
                            $config->getParameterValue($self->{JOB_NAME_KEY}),
                            $config->getParameterValue($self->{CURRENT_DIR_KEY}),
                            $config->getParameterValue($self->{COMMAND_KEY}),$state,
                            $self->{FileUtil}->getModificationTimeOfFile($jobFile),
                            $config->getParameterValue($self->{COMMANDS_FILE_KEY}),
                            $config->getParameterValue($self->{PSUB_FILE_KEY}),
                            $config->getParameterValue($self->{REAL_JOB_ID_KEY}),
                            $config->getParameterValue($self->{FAIL_REASON_KEY}),
                            $config->getParameterValue($self->{BATCH_FACTOR_KEY}),
                            $config->getParameterValue($self->{WALLTIME_KEY}),
                            $config->getParameterValue($self->{ACCOUNT_KEY}),
                            
                            $config->getParameterValue($self->{RAW_WRITE_OUTPUT_LOCAL_KEY}),
                            $config->getParameterValue($self->{RAW_COMMAND_KEY}),
                            $config->getParameterValue($self->{RAW_OUT_PATH_KEY}),
                            $config->getParameterValue($self->{RAW_ERROR_PATH_KEY}),
                            $config->getParameterValue($self->{RAW_WALLTIME_KEY}),
                            $config->getParameterValue($self->{RAW_BATCHFACTOR_KEY}),
                            $config->getParameterValue($self->{RAW_ACCOUNT_KEY}));
}


=head3 delete

Deletes the job by physically removing it from the database.
Returns undef for success otherwise a message upon failure.

$job = Panfish::Job->new();
$jobdb->delete($job);

=cut

sub delete {
   my $self = shift;
   my $job = shift;
   
   if (!defined($job)){
      return "No job passed in";
   }
 
   $self->{Logger}->debug("Deleting ".$self->{SubmitDir}."/".
                                           $job->getCluster()."/".
                                           $job->getState()."/".
                                           $job->getJobAndTaskId());
 
   my $res = $self->{FileUtil}->deleteFile($self->{SubmitDir}."/".
                                           $job->getCluster()."/".
                                           $job->getState()."/".
                                           $job->getJobAndTaskId());

   if ($res != 1){
       return "Unable to delete job $!";
   }
 
   return undef;
}


=head3 kill

Kills the job.  This tells everyone that the job processing
should be killed and no further work is to be done on the job.

=cut

sub kill {
    my $self = shift;
    my $job = shift;

    if (!defined($self->{FileReaderWriter})){
        return "FileReaderWriter not defined";
    }

    if (!defined($self->{SubmitDir})){
        return "SubmitDir not set";
    }

    if (!defined($job)){
        return "Job passed in is undefined";
    }

    
    my $outFile = $self->{SubmitDir}."/".$job->getCluster()."/".
                  Panfish::JobState->KILL()."/".
                  $job->getJobId().$self->_getTaskSuffix($job->getTaskId());

    if (defined($self->{Logger})){
        $self->{Logger}->debug("Attempting to kill job by writing to file: $outFile");
    }


   my $res = $self->{FileReaderWriter}->openFile(">$outFile");
   if (defined($res)){
     return $res;
   }

   $self->{FileReaderWriter}->write($self->{CURRENT_DIR_KEY}."=".$job->getCurrentWorkingDir()."\n");
   $self->{FileReaderWriter}->write($self->{JOB_NAME_KEY}."=".$job->getJobName()."\n");
   $self->{FileReaderWriter}->write($self->{COMMAND_KEY}."=".$job->getCommand()."\n");
   $self->{FileReaderWriter}->close();

   return undef;
}

1;

__END__


=head1 AUTHOR

Panfish::FileJobDatabase is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut

