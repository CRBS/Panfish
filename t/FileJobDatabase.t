#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl .t'

#########################


# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib $Bin;

use Test::More tests => 137;
use Panfish::FileReaderWriterImpl;
use Mock::FileReaderWriter;
use Panfish::FileUtil;
use Mock::FileUtil;
use Panfish::FileJobDatabase;
use Panfish::Logger;
use Mock::Logger;
use Panfish::ConfigFromFileFactory;
use Panfish::JobState;
use Panfish::Job;

#########################


# test _getTaskSuffix
{
    my $logoutput;
    my $foo;
    open $foo,'>',\$logoutput;
   my $blog = Panfish::Logger->new();
    $blog->setLevelBasedOnVerbosity(2);
    $blog->setOutput($foo); 
   my $testdir = $Bin."/testFileJobDatabase";
   my $readerWriter = Panfish::FileReaderWriterImpl->new($blog);
   my $fUtil = Panfish::FileUtil->new($blog);
   my $jobDb = Panfish::FileJobDatabase->new($readerWriter,$testdir,$fUtil,$blog);

   ok($jobDb->_getTaskSuffix(undef) eq "");

   ok($jobDb->_getTaskSuffix("") eq "");

   ok($jobDb->_getTaskSuffix("234") eq ".234");

   close($foo);
}

# test _getJobFromJobFile
{
   my $logoutput;
    my $foo;
    open $foo,'>',\$logoutput;
   my $blog = Panfish::Logger->new();
    $blog->setLevelBasedOnVerbosity(2);
    $blog->setOutput($foo);
   my $testdir = $Bin."/testFileJobDatabase";
   my $readerWriter = Panfish::FileReaderWriterImpl->new($blog);
   my $fUtil = Panfish::FileUtil->new($blog);
   $fUtil->recursiveRemoveDir($testdir);
   
   my $jobDb = Panfish::FileJobDatabase->new($readerWriter,$testdir,$fUtil,$blog);
   ok($jobDb->initializeDatabase("gee") == 1);

   # try with non existant file
   ok(!defined($jobDb->_getJobFromJobFile("$testdir/nonexistantjobfile","gee",Panfish::JobState->SUBMITTED())));
   my @rows = split("\n",$logoutput);
   ok(@rows == 3);
   ok($rows[2]=~/ERROR.*Unable to load config for file /);

   #try with a non numeric job id first gotta write out the file
   my $job = Panfish::Job->new("gee","e5549316-fd60-4c08-8891-bb3a24459d3e",
                               undef,"name","/tmp",undef,
                               Panfish::JobState->BATCHED(),undef,undef,
                               undef,undef);
   ok(!defined($jobDb->insert($job)));

   my $checkJob = $jobDb->_getJobFromJobFile("$testdir/gee/".Panfish::JobState->BATCHED()."/e5549316-fd60-4c08-8891-bb3a24459d3e","gee",
                                          Panfish::JobState->BATCHED());
   ok(defined($checkJob));
   ok($job->equals($checkJob)); 
   @rows = split("\n",$logoutput);
   ok(@rows == 6);
   ok($rows[5]=~/DEBUG.*Job e5549316-fd60-4c08-8891-bb3a24459d3e in cluster gee in state batched/);

   #try a valid job, but dont pass in the state to see if that is parsed correctly
   $job = Panfish::Job->new("gee",1,undef,"name","/tmp",undef,
                     Panfish::JobState->BATCHED(),undef,undef,undef,undef);
   ok(!defined($jobDb->insert($job)));
   $checkJob = $jobDb->_getJobFromJobFile("$testdir/gee/".Panfish::JobState->BATCHED()."/1","gee");
   ok(defined($checkJob));
   ok($job->equals($checkJob) == 1);

   @rows = split("\n",$logoutput);
   ok(@rows == 9);
   ok($rows[8]=~/DEBUG.*Job 1 in cluster gee in state batched/);

   
   close($foo);
}



# test insert
{
   my $logoutput;
    my $foo;
    open $foo,'>',\$logoutput;
   my $blog = Panfish::Logger->new();
    $blog->setLevelBasedOnVerbosity(2);
    $blog->setOutput($foo); 

   my $readerWriter = Panfish::FileReaderWriterImpl->new($blog);
   my $fUtil = Panfish::FileUtil->new($blog);
   my $testdir = $Bin."/testFileJobDatabase";
   
   $fUtil->recursiveRemoveDir($testdir);

   $jobDb = Panfish::FileJobDatabase->new($readerWriter,$testdir,$fUtil,$blog);
   ok($jobDb->initializeDatabase("gee") == 1);

   # test empty insert
   ok($jobDb->insert() eq "Job passed in is undefined");

   # test insertion of completely unset job
   my $job = Panfish::Job->new();
   ok($jobDb->insert($job) eq "Job does not have a cluster");

   $job = Panfish::Job->new("gee");
   ok($jobDb->insert($job) eq "Job does not have a state");

   $job = Panfish::Job->new("gee",undef,undef,undef,undef,undef,Panfish::JobState->SUBMITTED());
   ok($jobDb->insert($job) eq "Job id not set");

   $job = Panfish::Job->new("gee","1",undef,undef,undef,undef,Panfish::JobState->SUBMITTED());
   ok(!defined($jobDb->insert($job)));

   my $jobFromDb = $jobDb->getJobByClusterAndId("gee","1");
   ok(defined($jobFromDb));
   ok($job->equals($jobFromDb));
   
   #attempt to insert same job twice regardless of state
   ok($jobDb->insert($job) eq "Job 1 already exists in database in state submitted unable to insert");

   $job = Panfish::Job->new("gee","1",undef,undef,undef,undef,Panfish::JobState->QUEUED());
   ok($jobDb->insert($job) eq "Job 1 already exists in database in state submitted unable to insert");
 
   $job = Panfish::Job->new("gee","2","1",undef,undef,undef,Panfish::JobState->QUEUED());
   ok(!defined($jobDb->insert($job)));
   
   # test that differing task ids are okay
   $job = Panfish::Job->new("gee","2","2",undef,undef,undef,Panfish::JobState->QUEUED());
   ok(!defined($jobDb->insert($job)));

   $job = Panfish::Job->new("gee","2","1",undef,undef,undef,Panfish::JobState->DONE());
   ok($jobDb->insert($job) eq "Job 2.1 already exists in database in state queued unable to insert");

   close($foo);
}


# test getSummaryForCluster
{
   #set up the directory
   my $logoutput;
    my $foo;
    open $foo,'>',\$logoutput;
   my $blog = Panfish::Logger->new();
    $blog->setLevelBasedOnVerbosity(2);
    $blog->setOutput($foo);


   my $readerWriter = Panfish::FileReaderWriterImpl->new($blog);
   my $fUtil = Panfish::FileUtil->new($blog);
   my $testdir = $Bin."/testFileJobDatabase";
   my @jobs;
   my @jStates = Panfish::JobState->getAllStates();
   ok($fUtil->recursiveRemoveDir($testdir) > 0);

   my $jobDb = Panfish::FileJobDatabase->new($readerWriter,$testdir,$fUtil,$blog);
   ok($jobDb->initializeDatabase("foo") == 1);

   # test all the query methods return 0
   # check getSummaryForCluster
   ok($jobDb->getSummaryForCluster("foo") eq " (0) submitted (0) queued (0) batched (0) batchedandchummed (0) running (0) done (0) failed");

   my $job;  

   #lets add jobs to submitted state and check
   for (my $x = 0; $x < 10; $x++){
      $job = Panfish::Job->new("foo",100,$x,"name","/tmp",undef,
                     Panfish::JobState->SUBMITTED(),undef,undef,undef,undef);
      $jobDb->insert($job);
      ok($jobDb->getSummaryForCluster("foo") eq " (".($x+1).") submitted (0) queued (0) batched (0) batchedandchummed (0) running (0) done (0) failed");
   }
   #lets add jobs to queued state and check
   for (my $x = 0; $x < 10; $x++){
      $job = Panfish::Job->new("foo",101,$x,"name","/tmp",undef,
                     Panfish::JobState->QUEUED(),undef,undef,undef,undef);
      $jobDb->insert($job);
      ok($jobDb->getSummaryForCluster("foo") eq " (10) submitted (".($x+1).") queued (0) batched (0) batchedandchummed (0) running (0) done (0) failed");
   }
   #lets add jobs to batched and check
   for (my $x = 0; $x < 10; $x++){
      $job = Panfish::Job->new("foo",102,$x,"name","/tmp",undef,
                     Panfish::JobState->BATCHED(),undef,undef,undef,undef);
      $jobDb->insert($job);
      ok($jobDb->getSummaryForCluster("foo") eq " (10) submitted (10) queued (".($x+1).") batched (0) batchedandchummed (0) running (0) done (0) failed");
   }

   #lets add jobs to batchedandchummed and check
   for (my $x = 0; $x < 10; $x++){
      $job = Panfish::Job->new("foo",103,$x,"name","/tmp",undef,
                     Panfish::JobState->BATCHEDANDCHUMMED(),undef,undef,undef,undef);
      $jobDb->insert($job);
      ok($jobDb->getSummaryForCluster("foo") eq " (10) submitted (10) queued (10) batched (".($x+1).") batchedandchummed (0) running (0) done (0) failed");
   }
   
   #lets add jobs to running and check
   for (my $x = 0; $x < 10; $x++){
      $job = Panfish::Job->new("foo",104,$x,"name","/tmp",undef,
                     Panfish::JobState->RUNNING(),undef,undef,undef,undef);
      $jobDb->insert($job);
      ok($jobDb->getSummaryForCluster("foo") eq " (10) submitted (10) queued (10) batched (10) batchedandchummed (".($x+1).") running (0) done (0) failed");
   }
    
   #lets add jobs to done and check
   for (my $x = 0; $x < 10; $x++){
      $job = Panfish::Job->new("foo",105,$x,"name","/tmp",undef,
                     Panfish::JobState->DONE(),undef,undef,undef,undef);
      $jobDb->insert($job);
      ok($jobDb->getSummaryForCluster("foo") eq " (10) submitted (10) queued (10) batched (10) batchedandchummed (10) running (".($x+1).") done (0) failed");
   }
   
   #lets add jobs to done and check
   for (my $x = 0; $x < 10; $x++){
      $job = Panfish::Job->new("foo",106,$x,"name","/tmp",undef,
                     Panfish::JobState->FAILED(),undef,undef,undef,undef);
      $jobDb->insert($job);
      ok($jobDb->getSummaryForCluster("foo") eq " (10) submitted (10) queued (10) batched (10) batchedandchummed (10) running (10) done (".($x+1).") failed");
   }
   my @rows = split("\n",$logoutput);
   ok(@rows == 140);


   close($foo);
}

# getJobStateByClusterAndId tests where various inputs are not defined
{
    my $logger = Mock::Logger->new();
    my $readerWriter = Mock::FileReaderWriter->new();
    my $testdir = "/foo";
    my $fUtil = Mock::FileUtil->new();
    my $jobDb = Panfish::FileJobDatabase->new($readerWriter,$testdir,$fUtil,$logger);

    # test where jobId is not defined
    ok($jobDb->getJobStateByClusterAndId("cluster",undef,"taskId") eq Panfish::JobState->UNKNOWN());

   # test where cluster is not defined
   ok($jobDb->getJobStateByClusterAndId(undef,"jobid","taskId") eq Panfish::JobState->UNKNOWN());
   
   my @logs = $logger->getLogs();
   ok(@logs == 2);
   ok($logs[0] =~ /ERROR.*Job Id not defined/);
   ok($logs[1] =~ /ERROR.*Cluster Id not defined/);
}

# getJobStateByClusterAndId test where job is not found
{
    my $logger = Mock::Logger->new();
    my $readerWriter = Mock::FileReaderWriter->new();
    my $testdir = "/foo";
    my $fUtil = Mock::FileUtil->new();
    my $jobDb = Panfish::FileJobDatabase->new($readerWriter,$testdir,$fUtil,$logger);
   
   ok($jobDb->getJobStateByClusterAndId("cluster","1",undef) eq Panfish::JobState->UNKNOWN());

   my @logs = $logger->getLogs();
   ok(@logs == 2);
   ok($logs[0] =~ /DEBUG.*Looking for job: 1 under \/foo\/cluster/);
   ok($logs[1] =~ /WARN.*Unable to find job: 1 under \/foo\/cluster/);
}

# getJobStateByClusterAndId test where job is found
{
    my $logger = Mock::Logger->new();
    my $readerWriter = Mock::FileReaderWriter->new();
    my $testdir = "/foo";
    my $fUtil = Mock::FileUtil->new();

    $fUtil->addRunFileTestResult("-e","/foo/cluster/".Panfish::JobState->SUBMITTED()."/1",1);

    my $jobDb = Panfish::FileJobDatabase->new($readerWriter,$testdir,$fUtil,$logger);

   ok($jobDb->getJobStateByClusterAndId("cluster","1",undef) eq Panfish::JobState->SUBMITTED());

   my @logs = $logger->getLogs();
   ok(@logs == 1);
   ok($logs[0] =~ /DEBUG.*Looking for job: 1 under \/foo\/cluster/);
}

# getJobStatesByCluster no jobs
{
  my $logger = Mock::Logger->new();
  my $readerWriter = Mock::FileReaderWriter->new();
  my $testdir = "/foo";
  my $fUtil = Mock::FileUtil->new();
  my @emptyArr;
  $fUtil->addGetFilesInDirectoryResult($testdir."/cluster/".Panfish::JobState->SUBMITTED(),\@emptyArr);
  
  my $jobDb = Panfish::FileJobDatabase->new($readerWriter,$testdir,$fUtil,$logger);

  my $jobHash = $jobDb->getJobStatesByCluster("cluster");
  ok(defined($jobHash));
  ok(keys(%$jobHash) == 0);
}

# getJobStatesByCluster 1 job in submitted
{
  my $logger = Mock::Logger->new();
  my $readerWriter = Mock::FileReaderWriter->new();
  my $testdir = "/foo";
  my $fUtil = Mock::FileUtil->new();
  my @myArr;
  push(@myArr,$testdir."/cluster/".Panfish::JobState->SUBMITTED()."/1.2");
  $fUtil->addGetFilesInDirectoryResult($testdir."/cluster/".Panfish::JobState->SUBMITTED(),\@myArr);

  my $jobDb = Panfish::FileJobDatabase->new($readerWriter,$testdir,$fUtil,$logger);

  my $jobHash = $jobDb->getJobStatesByCluster("cluster");
  ok(defined($jobHash));
  ok(keys(%$jobHash) == 1);
  ok($jobHash->{"1.2"} eq Panfish::JobState->SUBMITTED());
}

# getJobStatesByCluster multiple jobs in different states
{
  my $logger = Mock::Logger->new();
  my $readerWriter = Mock::FileReaderWriter->new();
  my $testdir = "/foo";
  my $fUtil = Mock::FileUtil->new();
  my @myArr;
  push(@myArr,$testdir."/cluster/".Panfish::JobState->SUBMITTED()."/1.2");
  push(@myArr,$testdir."/cluster/".Panfish::JobState->SUBMITTED()."/1.3");
  $fUtil->addGetFilesInDirectoryResult($testdir."/cluster/".Panfish::JobState->SUBMITTED(),\@myArr);

  my @doneArr;
  push(@doneArr,$testdir."/cluster/".Panfish::JobState->DONE()."/4.4");
  push(@doneArr,$testdir."/cluster/".Panfish::JobState->DONE()."/4.5");
  push(@doneArr,$testdir."/cluster/".Panfish::JobState->DONE()."/6.4");
  $fUtil->addGetFilesInDirectoryResult($testdir."/cluster/".Panfish::JobState->DONE(),\@doneArr);
  my $jobDb = Panfish::FileJobDatabase->new($readerWriter,$testdir,$fUtil,$logger);

  my $jobHash = $jobDb->getJobStatesByCluster("cluster");
  ok(defined($jobHash));
  ok(keys(%$jobHash) == 5);
  ok($jobHash->{"1.2"} eq Panfish::JobState->SUBMITTED());
  ok($jobHash->{"1.3"} eq Panfish::JobState->SUBMITTED());
  ok($jobHash->{"4.4"} eq Panfish::JobState->DONE());
  ok($jobHash->{"4.5"} eq Panfish::JobState->DONE());
  ok($jobHash->{"6.4"} eq Panfish::JobState->DONE());
}

# getJobStatesByCluster 1 job in each state
{
  my $logger = Mock::Logger->new();
  my $readerWriter = Mock::FileReaderWriter->new();
  my $testdir = "/foo";
  my $fUtil = Mock::FileUtil->new();

  my @states = Panfish::JobState->getAllStates();
  my $numStates = @states;
  my $cntr = 1;
  for (my $x = 0; $x < @states; $x++){
    my @myArr;
    push(@myArr,$testdir."/cluster/".$states[$x]."/1.".$cntr++);
    $fUtil->addGetFilesInDirectoryResult($testdir."/cluster/".$states[$x],\@myArr);
  }

  my $jobDb = Panfish::FileJobDatabase->new($readerWriter,$testdir,$fUtil,$logger);

  my $jobHash = $jobDb->getJobStatesByCluster("cluster");
  ok(defined($jobHash));
  ok(keys(%$jobHash) == $numStates);
  $cntr = 1;
  for (my $x = 0; $x < @states; $x++){
    ok($jobHash->{"1.".$cntr++} eq $states[$x]);
  }
}



#sub update {
#sub updateArray {
#sub getJobsByClusterAndState {
#sub getNumberOfJobsInState {
#sub getJobByClusterAndId {
#sub getJobByClusterAndStateAndId {
#sub delete {
#sub kill {








