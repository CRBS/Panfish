#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl .t'

#########################


# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More tests => 103;
use Panfish::FileReaderWriterImpl;
use Panfish::FileUtil;
use Panfish::FileJobDatabase;
use Panfish::Logger;
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
   my $jobDb = Panfish::FileJobDatabase->new($readerWriter,$testdir,$blog);

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
   
   my $jobDb = Panfish::FileJobDatabase->new($readerWriter,$testdir,$blog);
   ok($jobDb->initializeDatabase("gee") == 1);

   # try with non existant file
   ok(!defined($jobDb->_getJobFromJobFile("$testdir/nonexistantjobfile","gee",Panfish::JobState->SUBMITTED())));
   my @rows = split("\n",$logoutput);
   ok(@rows == 3);
   ok($rows[2]=~/ERROR.*Unable to load config for file /);

   #try with a non numeric job id first gotta write out the file
   my $job = Panfish::Job->new("gee","grr",undef,"name","/tmp",undef,
                     Panfish::JobState->BATCHED(),undef,undef,undef,undef);
   ok(!defined($jobDb->insert($job)));

   ok(!defined($jobDb->_getJobFromJobFile("$testdir/gee/".Panfish::JobState->BATCHED()."/grr","gee",
                                          Panfish::JobState->BATCHED())));
 
   @rows = split("\n",$logoutput);
   ok(@rows == 6);
   ok($rows[5]=~/ERROR.*Job id is not numeric/);

   #try a valid job, but dont pass in the state to see if that is parsed correctly
   $job = Panfish::Job->new("gee",1,undef,"name","/tmp",undef,
                     Panfish::JobState->BATCHED(),undef,undef,undef,undef);
   ok(!defined($jobDb->insert($job)));
   my $checkJob = $jobDb->_getJobFromJobFile("$testdir/gee/".Panfish::JobState->BATCHED()."/1","gee");
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

   $jobDb = Panfish::FileJobDatabase->new($readerWriter,$testdir,$blog);
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
   ok($jobDb->insert($job) eq "Job 1 already exists in database unable to insert");

   $job = Panfish::Job->new("gee","1",undef,undef,undef,undef,Panfish::JobState->QUEUED());
   ok($jobDb->insert($job) eq "Job 1 already exists in database unable to insert");
 
   $job = Panfish::Job->new("gee","2","1",undef,undef,undef,Panfish::JobState->QUEUED());
   ok(!defined($jobDb->insert($job)));
   
   # test that differing task ids are okay
   $job = Panfish::Job->new("gee","2","2",undef,undef,undef,Panfish::JobState->QUEUED());
   ok(!defined($jobDb->insert($job)));

   $job = Panfish::Job->new("gee","2","1",undef,undef,undef,Panfish::JobState->DONE());
   ok($jobDb->insert($job) eq "Job 2.1 already exists in database unable to insert");

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

   my $jobDb = Panfish::FileJobDatabase->new($readerWriter,$testdir,$blog);
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



#sub update {
#sub updateArray {
#sub getJobsByClusterAndState {
#sub getNumberOfJobsInState {
#sub getJobByClusterAndId {
#sub getJobByClusterAndStateAndId {
#sub delete {
#sub kill {








