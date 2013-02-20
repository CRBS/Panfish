package Panfish::JobDatabase;

use strict;
use English;
use warnings;


use Panfish::FileUtil;
use Panfish::FileReaderWriter;
use Panfish::Logger;
use Panfish::ConfigFromFileFactory;
use Panfish::Config;

=head1 SYNOPSIS
   
  Panfish::JobDatabase -- Database to store Jobs

=head1 DESCRIPTION

Database for Jobs using files in the filesystem as the storage
medium.

=head1 METHODS

=head3 new

Creates new instance of JobDatabase

my $logger = Panfish::Logger->new();
my $readerWriter =  Panfish::FileReaderWriterImpl->new($logger);

my $jobDb = Panfish::JobDatabase->new($readerWriter,"/home/foo",$logger);

=cut

sub new {
   my $class = shift;
   my $self = {
     FileReaderWriter => shift,
     SubmitDir        => shift,
     Logger           => shift,
     FileUtil  => undef,
     ConfigFactory => undef
   };
   $self->{FileUtil} = Panfish::FileUtil->new($self->{Logger});
   $self->{ConfigFactory} = Panfish::ConfigFromFileFactory->new($self->{FileReaderWriter},$self->{Logger});
   my $blessedself = bless($self,$class);
   return $blessedself;
}




=head3 insert

Adds a new job to the database returning undef upon success otherwise
a string with the error upon failure.

$jobDb->insert($job);

=cut

sub insert {
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

   my $outFile = $self->{SubmitDir}."/".$job->getQueue()."/".
                 $job->getState()."/".
                 $job->getJobId().$self->_getTaskSuffix($job->getTaskId());

   if (defined($self->{Logger})){
     $self->{Logger}->debug("Attempting to insert job by writing to file: $outFile");
   }


   my $res = $self->{FileReaderWriter}->openFile(">$outFile");
   if (defined($res)){
     return $res;
   }

   $self->{FileReaderWriter}->write("current.working.dir=".$job->getCurrentWorkingDir()."\n");
   $self->{FileReaderWriter}->write("job.name=".$job->getJobName."\n");
   $self->{FileReaderWriter}->write("command=".$job->getCommand."\n");
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
   return "not implemented yet";

}

=head3 getJob

Gets a job from the database if any exist.  This is done
by searching the submit directory (set in the constructor) for
any files matching $JOBID.$TASKID.  When found the job object is
constructed by reading the contents of the file and looking at
which sub directory the file resides in.  This sub directory denotes
the state of the job.

my $job = $jobDb->getJobByQueueAndId("gordon_shadow.q","123",1");


=cut

sub getJobByQueueAndId {
   my $self = shift;
   my $queue = shift;
   my $jobId = shift;
   my $taskId = shift;


   my $jobFileName = "$jobId".$self->_getTaskSuffix($taskId);
   my $searchDir = $self->{SubmitDir}."/".$queue;
   if (defined($self->{Logger})){
      $self->{Logger}->debug("Looking for job: $jobFileName under $searchDir");
   }

   my $jobFile = $self->{FileUtil}->findFile($searchDir,$jobFileName);
   if (!defined($jobFile)){
     return undef;
   }

   my $state = $jobFile;
   $state =~s/^$self->{SubmitDir}\/$queue\///;
  
   $state =~s/\/$jobFileName//;
   
   if (defined($self->{Logger})){
      $self->{Logger}->debug("Job State is: $state");
   }
  

   my $config = $self->{ConfigFactory}->getConfig($jobFile);
   if (!defined($config)){
     return undef;
   }

   return Panfish::Job->new($queue,$jobId,$taskId,$config->getParameterValue("job.name"),
                            $config->getParameterValue("current.working.dir"),
                            $config->getParameterValue("command.to.run"),$state);
}

1;


=head3 delete

Deletes the job

=cut

sub delete {
   my $self = shift;
   my $queue = shift;
   my $jobid = shift;
   my $taskid = shift;
   return "not implemented";
}

__END__


=head1 AUTHOR

Panfish::JobDatabase is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut

