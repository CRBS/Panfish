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

Database for Jobs

=head1 METHODS

=head3 new

Creates new instance of JobDatabase

my $job = Panfish::Job->new()

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

Adds a new job to the database

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
                 $job->getJobId().".".$job->getTaskId().".job";

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


=head3 update

Updates the job in the database

=cut

sub update {
   my $self = shift;
   my $job = shift;

}

=head3 getJob

Gets a job from the database if any exist.

=cut

sub getJobByQueueAndId {
   my $self = shift;
   my $queue = shift;
   my $jobid = shift;
   my $taskid = shift;


   my $jobFileName = "$jobid.$taskid.job";
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
   $state =~s/\/$jobid\..*//;
   
   if (defined($self->{Logger})){
      $self->{Logger}->debug("Job State is: $state");
   }
  

   my $config = $self->{ConfigFactory}->getConfig($jobFile);
   if (!defined($config)){
     return undef;
   }

   return Panfish::Job->new($queue,$jobid,$taskid,$config->getParameterValue("job.name"),
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


}

__END__


=head1 AUTHOR

Panfish::JobDatabase is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut

