#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib $Bin;

use Test::More tests => 62;
use Panfish::JobBatchedChummer;
use Mock::Executor;
use Mock::Logger;
use Mock::FileUtil;
use Mock::JobDatabase;
use Mock::RemoteIO;
use Panfish::PanfishConfig;
use Panfish::Config;
use Panfish::JobState;
use Panfish::Job;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $timeout = 60; #default timeout
my $CLUSTER = "foo";
my $baseConfig = Panfish::Config->new();
$baseConfig->setParameter("this.cluster",$CLUSTER);
$baseConfig->setParameter($CLUSTER.".qstat","qstat");
$baseConfig->setParameter($CLUSTER.".basedir","base");
my $config = Panfish::PanfishConfig->new($baseConfig);

#
# Test cluster not defined
#
{
   my $logger = Mock::Logger->new(1);
   
   my $chummer = Panfish::JobBatchedChummer->new($config,undef,$logger,undef,undef);
   ok($chummer->chumBatchedJobs() eq "Cluster is not set");

   my @logs = $logger->getLogs();
   ok(@logs == 1);
   ok($logs[0] =~/ERROR Cluster is not set/);
}

#
# Test where there are no jobs in batched state
#
{
   my $logger = Mock::Logger->new(1);
   my $db = Mock::JobDatabase->new();
   
   my $chummer = Panfish::JobBatchedChummer->new($config,$db,$logger,undef,undef);

   ok(!defined($chummer->chumBatchedJobs($CLUSTER)));

   my @logs = $logger->getLogs();
   ok(@logs == 2);
   ok($logs[0] =~/DEBUG No jobs/);
   ok($logs[1] =~/DEBUG Looking for jobs in batchedandchummed state for $CLUSTER/);
}

#
# Test where only job is missing psub file
#
{
   my $logger = Mock::Logger->new(1);
   my $db = Mock::JobDatabase->new();
   my @clusterJobs = ();
   $clusterJobs[0] = Panfish::Job->new($CLUSTER,"1","2","name","cwd","command",
                                       Panfish::JobState->BATCHED(),1,undef,"psub",undef,undef);
   $db->addGetJobsByClusterAndStateResult($CLUSTER,Panfish::JobState->BATCHED(),\@clusterJobs);

   my $fu = Mock::FileUtil->new();

   # called to check for existance of psub file which should come back as a failure
   $fu->addRunFileTestResult("-f","psub","");


   my $chummer = Panfish::JobBatchedChummer->new($config,$db,$logger,$fu,undef);
   ok(!defined($chummer->chumBatchedJobs($CLUSTER)));

   my @logs = $logger->getLogs();
   ok(@logs == 2);
   ok($logs[0] =~/ERROR Job \(1.2\) missing psub file... skipping job/);
   ok($logs[1] =~/DEBUG Looking for jobs in batchedandchummed state for $CLUSTER/);
}

#
# Test where upload fails on a job
#
{
   my $logger = Mock::Logger->new(1);
   my $db = Mock::JobDatabase->new();
   my $remote = Mock::RemoteIO->new();

   my @clusterJobs = ();
   $clusterJobs[0] = Panfish::Job->new("foo2","1","2","name","cwd","command",
                                       Panfish::JobState->BATCHED(),1,undef,"psub",undef,undef);
   $db->addGetJobsByClusterAndStateResult("foo2",Panfish::JobState->BATCHED(),\@clusterJobs);

   my $fu = Mock::FileUtil->new();

   $fu->addRunFileTestResult("-f","psub",1);
   $fu->addGetDirnameResult("psub","psubdir");
   $fu->addGetDirnameResult("psubdir","dirpsubdir");

   $remote->addUploadResult("psubdir","foo2",undef,"uploadfail");


   my $chummer = Panfish::JobBatchedChummer->new($config,$db,$logger,$fu,$remote);
   ok(!defined($chummer->chumBatchedJobs("foo2")));

   my @logs = $logger->getLogs();
   ok(@logs == 5);
   ok($logs[0] =~/DEBUG Found 1 job\(s\) that need to be chummed/);
   ok($logs[1] =~/DEBUG Looking for jobs in batchedandchummed state for foo2/);
   ok($logs[2] =~/DEBUG Found 1 jobs with dir : psubdir/);
   ok($logs[3] =~/DEBUG Uploading psubdir to foo2/);
   ok($logs[4] =~/ERROR Problem uploading psubdir to foo2 : uploadfail/);
}

#
# Test where database update fails 
#
{
   my $logger = Mock::Logger->new(1);
   my $db = Mock::JobDatabase->new();
   my $remote = Mock::RemoteIO->new();

   my @clusterJobs = ();
   $clusterJobs[0] = Panfish::Job->new("foo2","1","2","name","cwd","command",
                                       Panfish::JobState->BATCHED(),1,undef,"psub",undef,undef);
   $db->addGetJobsByClusterAndStateResult("foo2",Panfish::JobState->BATCHED(),\@clusterJobs);
   $db->addUpdateResult($clusterJobs[0],"someerror");

   my $fu = Mock::FileUtil->new();

   $fu->addRunFileTestResult("-f","psub",1);
   $fu->addGetDirnameResult("psub","psubdir");
   $fu->addGetDirnameResult("psubdir","dirpsubdir");

   $remote->addUploadResult("psubdir","foo2",undef,undef);


   my $chummer = Panfish::JobBatchedChummer->new($config,$db,$logger,$fu,$remote);
   ok(!defined($chummer->chumBatchedJobs("foo2")));

   my @logs = $logger->getLogs();
   ok(@logs == 7);
   ok($logs[0] =~/DEBUG Found 1 job\(s\) that need to be chummed/);
   ok($logs[1] =~/DEBUG Looking for jobs in batchedandchummed state for foo2/);
   ok($logs[2] =~/DEBUG Found 1 jobs with dir : psubdir/);
   ok($logs[3] =~/DEBUG Uploading psubdir to foo2/);
   ok($logs[4] =~/DEBUG Upload succeeded updating database/);
   ok($logs[5] =~/ERROR Unable to update job \(1.2\) in database : someerror/);
   ok($logs[6] =~/INFO Chummed 1 batched jobs on foo2 for path dirpsubdir/);
}

#
# Test where there is 1 valid job in batched state on different cluster
#
{
   my $logger = Mock::Logger->new(1);
   my $db = Mock::JobDatabase->new();
   my $remote = Mock::RemoteIO->new();

   my @clusterJobs = ();
   $clusterJobs[0] = Panfish::Job->new("foo2","1","2","name","cwd","command",
                                       Panfish::JobState->BATCHED(),1,undef,"psub",undef,undef);
   $db->addGetJobsByClusterAndStateResult("foo2",Panfish::JobState->BATCHED(),\@clusterJobs);

   my $fu = Mock::FileUtil->new();

   $fu->addRunFileTestResult("-f","psub",1);   
   $fu->addGetDirnameResult("psub","psubdir");
   $fu->addGetDirnameResult("psubdir","dirpsubdir");

   $remote->addUploadResult("psubdir","foo2",undef,undef);


   my $chummer = Panfish::JobBatchedChummer->new($config,$db,$logger,$fu,$remote);
   ok(!defined($chummer->chumBatchedJobs("foo2")));

   my @logs = $logger->getLogs();
   
   ok(@logs == 6);
   ok($logs[0] =~/DEBUG Found 1 job\(s\) that need to be chummed/);
   ok($logs[1] =~/DEBUG Looking for jobs in batchedandchummed state for foo2/);
   ok($logs[2] =~/DEBUG Found 1 jobs with dir : psubdir/);
   ok($logs[3] =~/DEBUG Uploading psubdir to foo2/);
   ok($logs[4] =~/DEBUG Upload succeeded updating database/);
   ok($logs[5] =~/INFO Chummed 1 batched jobs on foo2 for path dirpsubdir/);
}

#
# Test where there is 1 valid job in batched state on this cluster
#
{
   my $logger = Mock::Logger->new(1);
   my $db = Mock::JobDatabase->new();

   my @clusterJobs = ();
   $clusterJobs[0] = Panfish::Job->new($CLUSTER,"1","2","name","cwd","command",
                                       Panfish::JobState->BATCHED(),1,undef,"psub",undef,undef);
   $db->addGetJobsByClusterAndStateResult($CLUSTER,Panfish::JobState->BATCHED(),\@clusterJobs);

   my $fu = Mock::FileUtil->new();

   $fu->addRunFileTestResult("-f","psub",1);
   $fu->addGetDirnameResult("psub","psubdir");
   $fu->addGetDirnameResult("psubdir","dirpsubdir");



   my $chummer = Panfish::JobBatchedChummer->new($config,$db,$logger,$fu,undef);
   ok(!defined($chummer->chumBatchedJobs($CLUSTER)));

   my @logs = $logger->getLogs();
   ok(@logs == 5);
   ok($logs[0] =~/DEBUG Found 1 job\(s\) that need to be chummed/);
   ok($logs[1] =~/DEBUG Looking for jobs in batchedandchummed state for foo/);
   ok($logs[2] =~/DEBUG Found 1 jobs with dir : psubdir/);
   ok($logs[3] =~/DEBUG No upload necessary updating database/);
   ok($logs[4] =~/INFO Chummed 1 batched jobs on foo for path dirpsubdir/);
}

#
# Test where there is multiple jobs with same psub directory
#
{
   my $logger = Mock::Logger->new(1);
   my $db = Mock::JobDatabase->new();
   my $remote = Mock::RemoteIO->new();

   my @clusterJobs = ();
   $clusterJobs[0] = Panfish::Job->new("foo2","1","2","name","cwd","command",
                                       Panfish::JobState->BATCHED(),1,undef,"psub",undef,undef);

   $clusterJobs[1] = Panfish::Job->new("foo2","2","1","name","cwd","command",
                                       Panfish::JobState->BATCHED(),1,undef,"psub.1",undef,undef);

   $clusterJobs[2] = Panfish::Job->new("foo2","2","2","name","cwd","command",
                                       Panfish::JobState->BATCHED(),1,undef,"psub.2",undef,undef);

   $db->addGetJobsByClusterAndStateResult("foo2",Panfish::JobState->BATCHED(),\@clusterJobs);

   my $fu = Mock::FileUtil->new();

   $fu->addRunFileTestResult("-f","psub",1);
   $fu->addRunFileTestResult("-f","psub.1",1);
   $fu->addRunFileTestResult("-f","psub.2",1);
   $fu->addGetDirnameResult("psub.1","psubdir");
   $fu->addGetDirnameResult("psub","psubdir");
   $fu->addGetDirnameResult("psub.2","psubdir");
   $fu->addGetDirnameResult("psubdir","dirpsubdir");

   $remote->addUploadResult("psubdir","foo2",undef,undef);


   my $chummer = Panfish::JobBatchedChummer->new($config,$db,$logger,$fu,$remote);
   ok(!defined($chummer->chumBatchedJobs("foo2")));

   my @logs = $logger->getLogs();
   ok(@logs == 6);
   ok($logs[0] =~/DEBUG Found 3 job\(s\) that need to be chummed/);
   ok($logs[1] =~/DEBUG Looking for jobs in batchedandchummed state for foo2/);
   ok($logs[2] =~/DEBUG Found 3 jobs with dir : psubdir/);
   ok($logs[3] =~/DEBUG Uploading psubdir to foo2/);
   ok($logs[4] =~/DEBUG Upload succeeded updating database/);
   ok($logs[5] =~/INFO Chummed 3 batched jobs on foo2 for path dirpsubdir/);
}

#
# Test where there is multiple jobs with multiple psub directories
#
{

   my $logger = Mock::Logger->new(1);
   my $db = Mock::JobDatabase->new();
   my $remote = Mock::RemoteIO->new();

   my @clusterJobs = ();
   $clusterJobs[0] = Panfish::Job->new("foo2","1","2","name","cwd","command",
                                       Panfish::JobState->BATCHED(),1,undef,"psub",undef,undef);

   $clusterJobs[1] = Panfish::Job->new("foo2","2","1","name","cwd","command",
                                       Panfish::JobState->BATCHED(),1,undef,"psub.1",undef,undef);

   $clusterJobs[2] = Panfish::Job->new("foo2","2","2","name","cwd","command",
                                       Panfish::JobState->BATCHED(),1,undef,"psub.2",undef,undef);

   $clusterJobs[3] = Panfish::Job->new("foo2","4","5","name","cwd","command",
                                       Panfish::JobState->BATCHED(),1,undef,"psub.3",undef,undef);

   $db->addGetJobsByClusterAndStateResult("foo2",Panfish::JobState->BATCHED(),\@clusterJobs);

   my $fu = Mock::FileUtil->new();

   $fu->addRunFileTestResult("-f","psub",1);
   $fu->addRunFileTestResult("-f","psub.1",1);
   $fu->addRunFileTestResult("-f","psub.2",1);
   $fu->addRunFileTestResult("-f","psub.3",1);
   $fu->addGetDirnameResult("psub.1","psubdir");
   $fu->addGetDirnameResult("psub","psubdir");
   $fu->addGetDirnameResult("psub.2","psubdir");
   $fu->addGetDirnameResult("psub.3","psubdir3");
   $fu->addGetDirnameResult("psubdir","dirpsubdir");
   $fu->addGetDirnameResult("psubdir3","dirpsubdir3");

   $remote->addUploadResult("psubdir","foo2",undef,undef);
   $remote->addUploadResult("psubdir3","foo2",undef,undef);


   my $chummer = Panfish::JobBatchedChummer->new($config,$db,$logger,$fu,$remote);
   ok(!defined($chummer->chumBatchedJobs("foo2")));

   my @logs = $logger->getLogs();
   ok(@logs == 10);
   ok($logs[0] =~/DEBUG Found 4 job\(s\) that need to be chummed/);
   ok($logs[1] =~/DEBUG Looking for jobs in batchedandchummed state for foo2/);
   ok($logs[2] =~/DEBUG Found 1 jobs with dir : psubdir3/);
   ok($logs[3] =~/DEBUG Uploading psubdir3 to foo2/);
   ok($logs[4] =~/DEBUG Upload succeeded updating database/);
   ok($logs[5] =~/INFO Chummed 1 batched jobs on foo2 for path dirpsubdir3/);
   ok($logs[6] =~/DEBUG Found 3 jobs with dir : psubdir/);
   ok($logs[7] =~/DEBUG Uploading psubdir to foo2/);
   ok($logs[8] =~/DEBUG Upload succeeded updating database/);
   ok($logs[9] =~/INFO Chummed 3 batched jobs on foo2 for path dirpsubdir/);
}




