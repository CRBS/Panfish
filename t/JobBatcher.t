#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib $Bin;

use Test::More tests => 68;
use Panfish::JobBatcher;
use Mock::Executor;
use Mock::Logger;
use Mock::FileUtil;
use Mock::JobDatabase;
use Mock::RemoteIO;
use Mock::JobHashFactory;
use Mock::CommandsFileFromJobsCreator;
use Mock::PsubFileFromJobsCreator;
use Mock::SortByFileAgeSorter;
use Panfish::PanfishConfig;
use Panfish::Config;
use Panfish::JobState;
use Panfish::Job;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $CLUSTER = "foo";

# Test _getBatchFactorForJob where batch factor is not defined, 0 and negative
# also test where batchfactor is 0.5 and greater then 1
{
  my $baseConfig = Panfish::Config->new();
  $baseConfig->setParameter("this.cluster",$CLUSTER);
  $baseConfig->setParameter($CLUSTER.".basedir","base");
  my $config = Panfish::PanfishConfig->new($baseConfig);


  my $batcher = Panfish::JobBatcher->new($config,undef,undef,undef,undef,undef);
  my $job;

  $job = Panfish::Job->new("foo","1","2","name","/cwd","command",
                           Panfish::JobState->SUBMITTED(),12345,
                           "/cwd/cmds".$config->getCommandsFileSuffix(),
                           undef,  # psubfile
                           undef,  # real job id
                           undef,  # fail reason
                           undef,  # batchfactor
                           undef,  # walltime
                           undef); # account

  ok($batcher->_getBatchFactorForJob($job) == 1);

  $job = Panfish::Job->new("foo","1","2","name","/cwd","command",
                           Panfish::JobState->SUBMITTED(),12345,
                           "/cwd/cmds".$config->getCommandsFileSuffix(),
                           undef,  # psubfile
                           undef,  # real job id
                           undef,  # fail reason
                           0,  # batchfactor
                           undef,  # walltime
                           undef); # account
  ok($batcher->_getBatchFactorForJob($job) == 1);

  $job = Panfish::Job->new("foo","1","2","name","/cwd","command",
                           Panfish::JobState->SUBMITTED(),12345,
                           "/cwd/cmds".$config->getCommandsFileSuffix(),
                           undef,  # psubfile
                           undef,  # real job id
                           undef,  # fail reason
                           1,  # batchfactor
                           undef,  # walltime
                           undef); # account
  ok($batcher->_getBatchFactorForJob($job) == 1);

  $job = Panfish::Job->new("foo","1","2","name","/cwd","command",
                           Panfish::JobState->SUBMITTED(),12345,
                           "/cwd/cmds".$config->getCommandsFileSuffix(),
                           undef,  # psubfile
                           undef,  # real job id
                           undef,  # fail reason
                           0.5,  # batchfactor
                           undef,  # walltime
                           undef); # account
  ok($batcher->_getBatchFactorForJob($job) == 2);

  $job = Panfish::Job->new("foo","1","2","name","/cwd","command",
                           Panfish::JobState->SUBMITTED(),12345,
                           "/cwd/cmds".$config->getCommandsFileSuffix(),
                           undef,  # psubfile
                           undef,  # real job id
                           undef,  # fail reason
                           2,  # batchfactor
                           undef,  # walltime
                           undef); # account
  ok($batcher->_getBatchFactorForJob($job) == 0.5);
}

# Test _createBatchableArrayOfJobs with some jobs
{
  my $baseConfig = Panfish::Config->new();
  $baseConfig->setParameter("this.cluster",$CLUSTER);
  $baseConfig->setParameter($CLUSTER.".jobs.per.node",2);
  my $config = Panfish::PanfishConfig->new($baseConfig);

  my $batcher = Panfish::JobBatcher->new($config,undef,undef,undef,undef,undef);

  my @jobs;
  $jobs[0] = Panfish::Job->new("foo","1","2","name","/cwd","command",
                           Panfish::JobState->SUBMITTED(),12345,
                           "/cwd/cmds".$config->getCommandsFileSuffix(),
                           undef,  # psubfile
                           undef,  # real job id
                           undef,  # fail reason
                           1,  # batchfactor
                           undef,  # walltime
                           undef); # account
  
  my @batchable = $batcher->_createBatchableArrayOfJobs($CLUSTER,\@jobs);
  ok(@batchable == 1);
  ok(@jobs == 0);

  $jobs[0] = Panfish::Job->new("foo","1","2","name","/cwd","command",
                           Panfish::JobState->SUBMITTED(),12345,
                           "/cwd/cmds".$config->getCommandsFileSuffix(),
                           undef,  # psubfile
                           undef,  # real job id
                           undef,  # fail reason
                           1,  # batchfactor
                           undef,  # walltime
                           undef); # account

  $jobs[1] = Panfish::Job->new("foo","1","3","name","/cwd","command",
                           Panfish::JobState->SUBMITTED(),12345,
                           "/cwd/cmds".$config->getCommandsFileSuffix(),
                           undef,  # psubfile
                           undef,  # real job id
                           undef,  # fail reason
                           1,  # batchfactor
                           undef,  # walltime
                           undef); # account

  @batchable = $batcher->_createBatchableArrayOfJobs($CLUSTER,\@jobs);
  ok(@batchable == 2);
  ok(@jobs == 0);
 
  #

  $jobs[0] = Panfish::Job->new("foo","1","2","name","/cwd","command",
                           Panfish::JobState->SUBMITTED(),12345,
                           "/cwd/cmds".$config->getCommandsFileSuffix(),
                           undef,  # psubfile
                           undef,  # real job id
                           undef,  # fail reason
                           1,  # batchfactor
                           undef,  # walltime
                           undef); # account

  $jobs[1] = Panfish::Job->new("foo","1","3","name","/cwd","command",
                           Panfish::JobState->SUBMITTED(),12345,
                           "/cwd/cmds".$config->getCommandsFileSuffix(),
                           undef,  # psubfile
                           undef,  # real job id
                           undef,  # fail reason
                           1,  # batchfactor
                           undef,  # walltime
                           undef); # account

  $jobs[2] = Panfish::Job->new("foo","1","4","name","/cwd","command",
                           Panfish::JobState->SUBMITTED(),12345,
                           "/cwd/cmds".$config->getCommandsFileSuffix(),
                           undef,  # psubfile
                           undef,  # real job id
                           undef,  # fail reason
                           1,  # batchfactor
                           undef,  # walltime
                           undef); # account


  @batchable = $batcher->_createBatchableArrayOfJobs($CLUSTER,\@jobs);
  ok(@batchable == 2);
  ok(@jobs == 1);
}

# Test _buildJobHash no jobs returned
{
  my $baseConfig = Panfish::Config->new();
  $baseConfig->setParameter("this.cluster",$CLUSTER);
  $baseConfig->setParameter($CLUSTER.".basedir","base");
  my $config = Panfish::PanfishConfig->new($baseConfig);

  my $logger = Mock::Logger->new(1);
  my $jobDb = Mock::JobDatabase->new();
  my @jobs;
  $jobDb->addGetJobsByClusterAndStateResult($CLUSTER,
                                            Panfish::JobState->SUBMITTED(),
                                            \@jobs);

  my $batcher = Panfish::JobBatcher->new($config,$jobDb,$logger,undef,undef,undef);
  ok(!defined($batcher->_buildJobHash($CLUSTER)));

  my @logs = $logger->getLogs();
  ok(@logs == 1);
  ok($logs[0] eq "DEBUG Found 0 job(s) in ".
                 Panfish::JobState->SUBMITTED().
                 " state for $CLUSTER");
}

# Test _buildJobHash 3 jobs returned in 2 hashes
{
  my $baseConfig = Panfish::Config->new();
  $baseConfig->setParameter("this.cluster",$CLUSTER);
  $baseConfig->setParameter($CLUSTER.".basedir","base");
  my $config = Panfish::PanfishConfig->new($baseConfig);

  my $logger = Mock::Logger->new(1);
  my $jobDb = Mock::JobDatabase->new();
  my @jobs;
 

  $jobs[0] = Panfish::Job->new("foo","1","2","name","/cwd","command",
                           Panfish::JobState->SUBMITTED(),12345,
                           "/cwd/cmds".$config->getCommandsFileSuffix(),
                           undef,  # psubfile
                           undef,  # real job id
                           undef,  # fail reason
                           1,  # batchfactor
                           undef,  # walltime
                           undef);
 
  $jobDb->addGetJobsByClusterAndStateResult($CLUSTER,
                                            Panfish::JobState->SUBMITTED(),
                                            \@jobs);

  my $jobHash = Mock::JobHashFactory->new();

  $jobHash->addGetJobHashResult(\@jobs,"blah",undef);

  my $batcher = Panfish::JobBatcher->new($config,$jobDb,$logger,undef,undef,
                                         $jobHash,undef);

  my $checkHash = $batcher->_buildJobHash($CLUSTER);
  ok(defined($checkHash));

  my @logs = $logger->getLogs();
  ok(@logs == 1);
  ok($logs[0] eq "DEBUG Found 1 job(s) in ".
                 Panfish::JobState->SUBMITTED().
                 " state for $CLUSTER");
}

# Test _isItOkayToSubmitJobs no jobs ie undef and 0 size
{
    my $baseConfig = Panfish::Config->new();
  $baseConfig->setParameter("this.cluster",$CLUSTER);
  $baseConfig->setParameter($CLUSTER.".basedir","base");
  my $config = Panfish::PanfishConfig->new($baseConfig);

  my $logger = Mock::Logger->new(1);


  my $batcher = Panfish::JobBatcher->new($config,undef,$logger,undef,undef,undef);
 
  my @jobs;
  ok($batcher->_isItOkayToSubmitJobs($CLUSTER,\@jobs) eq "no");
  ok($batcher->_isItOkayToSubmitJobs($CLUSTER,undef) eq "no");
  my @logs = $logger->getLogs();
  ok(@logs == 2);
  ok($logs[0] eq "DEBUG There are no jobs to submit");
  ok($logs[1] eq "DEBUG There are no jobs to submit");



}

# Test _isItOkayToSubmitJobs job count exceeds threshold so jobs are allowed
{
  my $baseConfig = Panfish::Config->new();
  $baseConfig->setParameter("this.cluster",$CLUSTER);
  $baseConfig->setParameter($CLUSTER.".basedir","base");
  $baseConfig->setParameter($CLUSTER.".jobs.per.node",2);
  my $config = Panfish::PanfishConfig->new($baseConfig);

  my $logger = Mock::Logger->new(1);


  my $batcher = Panfish::JobBatcher->new($config,undef,$logger,undef,undef,undef);

  my @jobs;
  $jobs[0] = Panfish::Job->new("foo","1","2","name","/cwd","command",
                           Panfish::JobState->SUBMITTED(),12345,
                           "/cwd/cmds".$config->getCommandsFileSuffix(),
                           undef,  # psubfile
                           undef,  # real job id
                           undef,  # fail reason
                           1,  # batchfactor
                           undef,  # walltime
                           undef); # account

  $jobs[1] = Panfish::Job->new("foo","1","3","name","/cwd","command",
                           Panfish::JobState->SUBMITTED(),12345,
                           "/cwd/cmds".$config->getCommandsFileSuffix(),
                           undef,  # psubfile
                           undef,  # real job id
                           undef,  # fail reason
                           1,  # batchfactor
                           undef,  # walltime
                           undef); # account


  ok($batcher->_isItOkayToSubmitJobs($CLUSTER,\@jobs) eq "yes");
  my @logs = $logger->getLogs();
  ok(@logs == 1);
  ok($logs[0] eq "DEBUG Job count: 2 exceeds threshold of 2 for cluster $CLUSTER.  Allowing jobs to be submitted");
}

# Test _isItOkayToSubmitJobs jobs per node not set for cluster
{
  my $baseConfig = Panfish::Config->new();
  $baseConfig->setParameter("this.cluster",$CLUSTER);
  $baseConfig->setParameter($CLUSTER.".basedir","base");
  my $config = Panfish::PanfishConfig->new($baseConfig);

  my $logger = Mock::Logger->new(1);


  my $batcher = Panfish::JobBatcher->new($config,undef,$logger,undef,undef,undef);

  my @jobs;
  $jobs[0] = Panfish::Job->new("foo","1","2","name","/cwd","command",
                           Panfish::JobState->SUBMITTED(),12345,
                           "/cwd/cmds".$config->getCommandsFileSuffix(),
                           undef,  # psubfile
                           undef,  # real job id
                           undef,  # fail reason
                           1,  # batchfactor
                           undef,  # walltime
                           undef); # account

  $jobs[1] = Panfish::Job->new("foo","1","3","name","/cwd","command",
                           Panfish::JobState->SUBMITTED(),12345,
                           "/cwd/cmds".$config->getCommandsFileSuffix(),
                           undef,  # psubfile
                           undef,  # real job id
                           undef,  # fail reason
                           1,  # batchfactor
                           undef,  # walltime
                           undef); # account


  ok($batcher->_isItOkayToSubmitJobs($CLUSTER,\@jobs) eq "no");
  my @logs = $logger->getLogs();
  ok(@logs == 1);
  ok($logs[0] eq "ERROR Jobs per node not set for cluster $CLUSTER : ignoring jobs");
}


# Test _isItOkayToSubmitJobs override timeout not set for cluster
{
  my $baseConfig = Panfish::Config->new();
  $baseConfig->setParameter("this.cluster",$CLUSTER);
  $baseConfig->setParameter($CLUSTER.".basedir","base");
  $baseConfig->setParameter($CLUSTER.".jobs.per.node",3);
 
  my $config = Panfish::PanfishConfig->new($baseConfig);
  
  my $logger = Mock::Logger->new(1);


  my $batcher = Panfish::JobBatcher->new($config,undef,$logger,undef,undef,undef);

  my @jobs;
  $jobs[0] = Panfish::Job->new("foo","1","2","name","/cwd","command",
                           Panfish::JobState->SUBMITTED(),12345,
                           "/cwd/cmds".$config->getCommandsFileSuffix(),
                           undef,  # psubfile
                           undef,  # real job id
                           undef,  # fail reason
                           1,  # batchfactor
                           undef,  # walltime
                           undef); # account

  $jobs[1] = Panfish::Job->new("foo","1","3","name","/cwd","command",
                           Panfish::JobState->SUBMITTED(),12345,
                           "/cwd/cmds".$config->getCommandsFileSuffix(),
                           undef,  # psubfile
                           undef,  # real job id
                           undef,  # fail reason
                           1,  # batchfactor
                           undef,  # walltime
                           undef); # account


  ok($batcher->_isItOkayToSubmitJobs($CLUSTER,\@jobs) eq "no");
  my @logs = $logger->getLogs();
  ok(@logs == 1);
  ok($logs[0] eq "ERROR Override timeout not set for cluster : $CLUSTER : ignoring jobs");


}

# Test _isItOkayToSubmitJobs where jobs do not exceed override time out
{
  my $baseConfig = Panfish::Config->new();
  $baseConfig->setParameter("this.cluster",$CLUSTER);
  $baseConfig->setParameter($CLUSTER.".basedir","base");
  $baseConfig->setParameter($CLUSTER.".jobs.per.node",3);
  $baseConfig->setParameter($CLUSTER.".job.batcher.override.timeout",1000);

  my $config = Panfish::PanfishConfig->new($baseConfig);

  my $logger = Mock::Logger->new(1);


  my $batcher = Panfish::JobBatcher->new($config,undef,$logger,undef,undef,undef);

  my @jobs;
  my $curTimeInSec = time();
  $jobs[0] = Panfish::Job->new("foo","1","2","name","/cwd","command",
                           Panfish::JobState->SUBMITTED(),12345,
                           "/cwd/cmds".$config->getCommandsFileSuffix(),
                           undef,  # psubfile
                           undef,  # real job id
                           undef,  # fail reason
                           1,  # batchfactor
                           undef,  # walltime
                           undef); # account

  $jobs[1] = Panfish::Job->new("foo","1","3","name","/cwd","command",
                           Panfish::JobState->SUBMITTED(),$curTimeInSec,
                           "/cwd/cmds".$config->getCommandsFileSuffix(),
                           undef,  # psubfile
                           undef,  # real job id
                           undef,  # fail reason
                           1,  # batchfactor
                           undef,  # walltime
                           undef); # account


  ok($batcher->_isItOkayToSubmitJobs($CLUSTER,\@jobs) eq "no");
  my @logs = $logger->getLogs();
  ok(@logs == 2);
  ok($logs[0] =~/DEBUG Current Time .* and Override Time: 1000/);
  ok($logs[1] =~/DEBUG Job 1.3 age is .* seconds which is less then override timeout of 1000 seconds : not releasing jobs/);
}



# Test _isItOkayToSubmitJobs where jobs do exceed override time out
{
  my $baseConfig = Panfish::Config->new();
  $baseConfig->setParameter("this.cluster",$CLUSTER);
  $baseConfig->setParameter($CLUSTER.".basedir","base");
  $baseConfig->setParameter($CLUSTER.".jobs.per.node",3);
  $baseConfig->setParameter($CLUSTER.".job.batcher.override.timeout",1000);

  my $config = Panfish::PanfishConfig->new($baseConfig);

  my $logger = Mock::Logger->new(1);


  my $batcher = Panfish::JobBatcher->new($config,undef,$logger,undef,undef,undef);

  my @jobs;
  my $curTimeInSec = time();
  $jobs[0] = Panfish::Job->new("foo","1","2","name","/cwd","command",
                           Panfish::JobState->SUBMITTED(),$curTimeInSec-1000,
                           "/cwd/cmds".$config->getCommandsFileSuffix(),
                           undef,  # psubfile
                           undef,  # real job id
                           undef,  # fail reason
                           1,  # batchfactor
                           undef,  # walltime
                           undef); # account

  $jobs[1] = Panfish::Job->new("foo","1","3","name","/cwd","command",
                           Panfish::JobState->SUBMITTED(),$curTimeInSec-1000,
                           "/cwd/cmds".$config->getCommandsFileSuffix(),
                           undef,  # psubfile
                           undef,  # real job id
                           undef,  # fail reason
                           1,  # batchfactor
                           undef,  # walltime
                           undef); # account


  ok($batcher->_isItOkayToSubmitJobs($CLUSTER,\@jobs) eq "yes");
  my @logs = $logger->getLogs();
  ok(@logs == 1);
  ok($logs[0] =~/DEBUG Current Time .* and Override Time: 1000/);
}


# Test batchJobs where cluster not defined
{
  my $baseConfig = Panfish::Config->new();
  $baseConfig->setParameter("this.cluster",$CLUSTER);
  $baseConfig->setParameter($CLUSTER.".basedir","base");
  my $config = Panfish::PanfishConfig->new($baseConfig);

  my $logger = Mock::Logger->new(1);
   
 
  my $batcher = Panfish::JobBatcher->new($config,undef,$logger,undef,undef,undef);
  ok($batcher->batchJobs() eq "Cluster is not set");

  my @logs = $logger->getLogs();
  ok(@logs == 1);
  ok($logs[0] =~/ERROR Cluster is not set/);
}

# Test batchJobs where no jobs returned from_buildJobHash
{
  my $baseConfig = Panfish::Config->new();
  $baseConfig->setParameter("this.cluster",$CLUSTER);
  $baseConfig->setParameter($CLUSTER.".basedir","base");
  my $config = Panfish::PanfishConfig->new($baseConfig);

  my $logger = Mock::Logger->new(1);

  my $jobDb = Mock::JobDatabase->new();
  my @jobs;
  $jobDb->addGetJobsByClusterAndStateResult($CLUSTER,
                                            Panfish::JobState->SUBMITTED(),
                                            \@jobs);

  my $batcher = Panfish::JobBatcher->new($config,$jobDb,$logger,undef,undef,undef);

  ok(!defined($batcher->batchJobs($CLUSTER)));
  my @logs = $logger->getLogs();
  ok(@logs == 1);
  ok($logs[0] eq "DEBUG Found 0 job(s) in ".
                 Panfish::JobState->SUBMITTED().
                 " state for $CLUSTER");
}

# Test batchJobs where Commands file creator fails
{
  my $baseConfig = Panfish::Config->new();
  $baseConfig->setParameter("this.cluster",$CLUSTER);
  $baseConfig->setParameter($CLUSTER.".basedir","base");
  $baseConfig->setParameter($CLUSTER.".jobs.per.node",1);
  $baseConfig->setParameter($CLUSTER.".job.batcher.override.timeout",0);

  my $config = Panfish::PanfishConfig->new($baseConfig);

  my $logger = Mock::Logger->new(1);

  my $jobDb = Mock::JobDatabase->new();
  my @jobs;
  my $curTimeInSec = time();
  $jobs[0] = Panfish::Job->new("foo","1","2","name","/cwd","command",
                           Panfish::JobState->SUBMITTED(),$curTimeInSec-1000,
                           "/cwd/cmds".$config->getCommandsFileSuffix(),
                           undef,  # psubfile
                           undef,  # real job id
                           undef,  # fail reason
                           1,  # batchfactor
                           undef,  # walltime
                           undef); # account

  $jobDb->addGetJobsByClusterAndStateResult($CLUSTER,
                                            Panfish::JobState->SUBMITTED(),
                                            \@jobs);

  my $jobHash = Mock::JobHashFactory->new();

  my %jobHash = ();
  push(@{$jobHash{"/cwd"}},$jobs[0]);

  $jobHash->addGetJobHashResult(\@jobs,\%jobHash,undef);
  
  my $cmdCreator = Mock::CommandsFileFromJobsCreator->new();

  $cmdCreator->addCreateResult($CLUSTER,\@jobs,"error");

  my $sorter = Mock::SortByFileAgeSorter->new();
  my @paths;
  $paths[0] = "/cwd";
  $sorter->addSortResult(undef,\@paths);
 
  my $batcher = Panfish::JobBatcher->new($config,$jobDb,$logger,$cmdCreator,undef,$jobHash,$sorter);
  ok(!defined($batcher->batchJobs($CLUSTER)));
  my @logs = $logger->getLogs();
  ok(@logs == 4); 
  ok($logs[0] eq "DEBUG Found 1 job(s) in ".
                 Panfish::JobState->SUBMITTED().
                 " state for $CLUSTER");
  ok($logs[1] eq "DEBUG Job count: 1 exceeds threshold of 1 for cluster $CLUSTER.  Allowing jobs to be submitted");
  ok($logs[2] eq "ERROR Unable to create commands file : error");
  ok($logs[3] eq "DEBUG There are no jobs to submit");
}

# Test batchJobs where psub file creator fails
{
  my $baseConfig = Panfish::Config->new();
  $baseConfig->setParameter("this.cluster",$CLUSTER);
  $baseConfig->setParameter($CLUSTER.".basedir","base");
  $baseConfig->setParameter($CLUSTER.".jobs.per.node",1);
  $baseConfig->setParameter($CLUSTER.".job.batcher.override.timeout",0);

  my $config = Panfish::PanfishConfig->new($baseConfig);

  my $logger = Mock::Logger->new(1);

  my $jobDb = Mock::JobDatabase->new();
  my @jobs;
  my $curTimeInSec = time();
  $jobs[0] = Panfish::Job->new("foo","1","2","name","/cwd","command",
                           Panfish::JobState->SUBMITTED(),$curTimeInSec-1000,
                           "/cwd/cmds".$config->getCommandsFileSuffix(),
                           undef,  # psubfile
                           undef,  # real job id
                           undef,  # fail reason
                           1,  # batchfactor
                           undef,  # walltime
                           undef); # account

  $jobDb->addGetJobsByClusterAndStateResult($CLUSTER,
                                            Panfish::JobState->SUBMITTED(),
                                            \@jobs);

  my $jobHash = Mock::JobHashFactory->new();

  my %jobHash = ();
  push(@{$jobHash{"/cwd"}},$jobs[0]);

  $jobHash->addGetJobHashResult(\@jobs,\%jobHash,undef);

  my $cmdCreator = Mock::CommandsFileFromJobsCreator->new();

  $cmdCreator->addCreateResult($CLUSTER,\@jobs,undef);

  my $psubCreator = Mock::PsubFileFromJobsCreator->new();
  $psubCreator->addCreateResult($CLUSTER,\@jobs,"error");

  my $sorter = Mock::SortByFileAgeSorter->new();
  my @paths;
  $paths[0] = "/cwd";
  $sorter->addSortResult(undef,\@paths);
 
  my $batcher = Panfish::JobBatcher->new($config,$jobDb,$logger,
                                         $cmdCreator,$psubCreator,
                                         $jobHash,$sorter);
  ok(!defined($batcher->batchJobs($CLUSTER)));
  my @logs = $logger->getLogs();
  ok(@logs == 4);
  ok($logs[0] eq "DEBUG Found 1 job(s) in ".
                 Panfish::JobState->SUBMITTED().
                 " state for $CLUSTER");
  ok($logs[1] eq "DEBUG Job count: 1 exceeds threshold of 1 for cluster $CLUSTER.  Allowing jobs to be submitted");
  ok($logs[2] eq "ERROR Unable to create psub file : error");
  ok($logs[3] eq "DEBUG There are no jobs to submit");
}

# Test batchJobs where database update fails
{
  my $baseConfig = Panfish::Config->new();
  $baseConfig->setParameter("this.cluster",$CLUSTER);
  $baseConfig->setParameter($CLUSTER.".basedir","base");
  $baseConfig->setParameter($CLUSTER.".jobs.per.node",1);
  $baseConfig->setParameter($CLUSTER.".job.batcher.override.timeout",0);

  my $config = Panfish::PanfishConfig->new($baseConfig);

  my $logger = Mock::Logger->new(1);

  my $jobDb = Mock::JobDatabase->new();
  my @jobs;
  my $curTimeInSec = time();
  $jobs[0] = Panfish::Job->new("foo","1","2","name","/cwd","command",
                           Panfish::JobState->SUBMITTED(),$curTimeInSec-1000,
                           "/cwd/cmds".$config->getCommandsFileSuffix(),
                           undef,  # psubfile
                           undef,  # real job id
                           undef,  # fail reason
                           1,  # batchfactor
                           undef,  # walltime
                           undef); # account

  $jobDb->addGetJobsByClusterAndStateResult($CLUSTER,
                                            Panfish::JobState->SUBMITTED(),
                                            \@jobs);
  $jobDb->addUpdateArrayResult(undef,"error");

  my $jobHash = Mock::JobHashFactory->new();

  my %jobHash = ();
  push(@{$jobHash{"/cwd"}},$jobs[0]);

  $jobHash->addGetJobHashResult(\@jobs,\%jobHash,undef);

  my $cmdCreator = Mock::CommandsFileFromJobsCreator->new();

  $cmdCreator->addCreateResult($CLUSTER,\@jobs,undef);

  my $psubCreator = Mock::PsubFileFromJobsCreator->new();
  $psubCreator->addCreateResult($CLUSTER,\@jobs,undef);

  my $sorter = Mock::SortByFileAgeSorter->new();
  my @paths;
  $paths[0] = "/cwd";
  $sorter->addSortResult(undef,\@paths);

  my $batcher = Panfish::JobBatcher->new($config,$jobDb,$logger,
                                         $cmdCreator,$psubCreator,
                                         $jobHash,$sorter);
  ok(!defined($batcher->batchJobs($CLUSTER)));
  my @logs = $logger->getLogs();
  ok(@logs == 4);
  ok($logs[0] eq "DEBUG Found 1 job(s) in ".
                 Panfish::JobState->SUBMITTED().
                 " state for $CLUSTER");
  ok($logs[1] eq "DEBUG Job count: 1 exceeds threshold of 1 for cluster $CLUSTER.  Allowing jobs to be submitted");
  ok($logs[2] eq "ERROR Unable to update jobs in database : error");
  ok($logs[3] eq "DEBUG There are no jobs to submit");
}

# Test batchJobs where all is successful
{
  my $baseConfig = Panfish::Config->new();
  $baseConfig->setParameter("this.cluster",$CLUSTER);
  $baseConfig->setParameter($CLUSTER.".basedir","base");
  $baseConfig->setParameter($CLUSTER.".jobs.per.node",1);
  $baseConfig->setParameter($CLUSTER.".job.batcher.override.timeout",0);

  my $config = Panfish::PanfishConfig->new($baseConfig);

  my $logger = Mock::Logger->new(1);

  my $jobDb = Mock::JobDatabase->new();
  my @jobs;
  my $curTimeInSec = time();
  $jobs[0] = Panfish::Job->new("foo","1","2","name","/cwd","command",
                           Panfish::JobState->SUBMITTED(),$curTimeInSec-1000,
                           "/cwd/cmds".$config->getCommandsFileSuffix(),
                           undef,  # psubfile
                           undef,  # real job id
                           undef,  # fail reason
                           1,  # batchfactor
                           undef,  # walltime
                           undef); # account

  $jobDb->addGetJobsByClusterAndStateResult($CLUSTER,
                                            Panfish::JobState->SUBMITTED(),
                                            \@jobs);
  $jobDb->addUpdateArrayResult(undef,undef);

  my $jobHash = Mock::JobHashFactory->new();

  my %jobHash = ();
  push(@{$jobHash{"/cwd"}},$jobs[0]);

  $jobHash->addGetJobHashResult(\@jobs,\%jobHash,undef);

  my $cmdCreator = Mock::CommandsFileFromJobsCreator->new();

  $cmdCreator->addCreateResult($CLUSTER,\@jobs,undef);

  my $psubCreator = Mock::PsubFileFromJobsCreator->new();
  $psubCreator->addCreateResult($CLUSTER,\@jobs,undef);

  my $sorter = Mock::SortByFileAgeSorter->new();
  my @paths;
  $paths[0] = "/cwd";
  $sorter->addSortResult(undef,\@paths);

  my $batcher = Panfish::JobBatcher->new($config,$jobDb,$logger,
                                         $cmdCreator,$psubCreator,
                                         $jobHash,$sorter);
  ok(!defined($batcher->batchJobs($CLUSTER)));
  my @logs = $logger->getLogs();
  ok(@logs == 4);
  ok($logs[0] eq "DEBUG Found 1 job(s) in ".
                 Panfish::JobState->SUBMITTED().
                 " state for $CLUSTER");
  ok($logs[1] eq "DEBUG Job count: 1 exceeds threshold of 1 for cluster $CLUSTER.  Allowing jobs to be submitted");
  ok($logs[2] eq "INFO Batched 1 jobs on $CLUSTER with base id: 1.2");
  ok($logs[3] eq "DEBUG There are no jobs to submit");
}

