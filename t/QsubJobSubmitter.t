#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib $Bin;

use Test::More tests => 22;
use Panfish::QsubJobSubmitter;
use Panfish::PanfishConfig;
use Panfish::Config;
use Panfish::JobState;
use Panfish::Job;

use Mock::FileUtil;
use Mock::NoSortPathSorter;
use Mock::JobHashFactory;
use Mock::Executor;
use Mock::Logger;
use Mock::JobDatabase;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $timeout = 60; #default timeout

# test submitJobs cluster not set  
{
    my $exec = Mock::Executor->new();
    my $logger = Mock::Logger->new();
    my $fUtil = Mock::FileUtil->new();
    my $pathSorter = Mock::NoSortPathSorter->new();
    my $hashFac = Mock::JobHashFactory->new();
    my $pConfig;
    my $submitter = Panfish::QsubJobSubmitter->new($pConfig,$jobDb,$logger,$fUtil,$exec,$hashFac,$pathSorter);
 
    ok($submitter->submitJobs(undef) eq "Cluster is not set");
    my @rows = $logger->getLogs();
    ok(@rows == 1);
    ok($rows[0] =~/ERROR Cluster is not set/);
}

# test submitJobs cluster specified is not the local cluster
{
    my $exec = Mock::Executor->new();
    my $logger = Mock::Logger->new();
    my $fUtil = Mock::FileUtil->new();
    my $pathSorter = Mock::NoSortPathSorter->new();
    my $hashFac = Mock::JobHashFactory->new();
    my $config = Panfish::Config->new();
    my $pConfig = Panfish::PanfishConfig->new();
    
    $config->setParameter($pConfig->{THIS_CLUSTER},"othercluster");
    $config->setParameter("foo.".$pConfig->{HOST},"blah");
    $pConfig->setConfig($config);

    my $submitter = Panfish::QsubJobSubmitter->new($pConfig,$jobDb,$logger,$fUtil,$exec,$hashFac,$pathSorter);

    ok(!defined($submitter->submitJobs("foo")));
    my @rows = $logger->getLogs();
    ok(@rows == 1);
    ok($rows[0] =~/WARN This should only be run on jobs for local cluster returning./);
}

# test submitJobs where Number of jobs in queued/running state exceed max running jobs already
{
    my $exec = Mock::Executor->new();
    my $logger = Mock::Logger->new();
    my $fUtil = Mock::FileUtil->new();
    my $pathSorter = Mock::NoSortPathSorter->new();
    my $hashFac = Mock::JobHashFactory->new();
    my $config = Panfish::Config->new();
    my $pConfig = Panfish::PanfishConfig->new();
    
    $config->setParameter($pConfig->{THIS_CLUSTER},"cluster");
    $config->setParameter("cluster.".$pConfig->{MAX_NUM_RUNNING_JOBS},10);
    $pConfig->setConfig($config);
    
    my $jobDb = Mock::JobDatabase->new();


    # try where queued jobs is set to 10 and running is set 0
    $jobDb->addGetNumberOfJobsInStateResult("cluster",Panfish::JobState->QUEUED(),10);
    $jobDb->addGetNumberOfJobsInStateResult("cluster",Panfish::JobState->RUNNING(),0);    
    my $submitter = Panfish::QsubJobSubmitter->new($pConfig,$jobDb,$logger,$fUtil,$exec,$hashFac,$pathSorter);
    ok(!defined($submitter->submitJobs("cluster")));
    my @rows = $logger->getLogs();
    ok(@rows == 2);
    ok($rows[0] =~/DEBUG Max num jobs allowed: 10/);
    ok($rows[1] =~/DEBUG 10 jobs running which exceeds 10 not submitting any jobs/);

    
    # try where queued jobs is set to 0 and running is set 10
    $logger->clearLog();
    $jobDb->addGetNumberOfJobsInStateResult("cluster",Panfish::JobState->QUEUED(),0);
    $jobDb->addGetNumberOfJobsInStateResult("cluster",Panfish::JobState->RUNNING(),10);
    ok(!defined($submitter->submitJobs("cluster")));
    @rows = $logger->getLogs();
    ok(@rows == 2);
    ok($rows[0] =~/DEBUG Max num jobs allowed: 10/);
    ok($rows[1] =~/DEBUG 10 jobs running which exceeds 10 not submitting any jobs/);

    # try where queued jobs is set to 7 and running is set 3
    $logger->clearLog();
    $jobDb->addGetNumberOfJobsInStateResult("cluster",Panfish::JobState->QUEUED(),7);
    $jobDb->addGetNumberOfJobsInStateResult("cluster",Panfish::JobState->RUNNING(),3);
    ok(!defined($submitter->submitJobs("cluster")));
    @rows = $logger->getLogs();
    ok(@rows == 2);
    ok($rows[0] =~/DEBUG Max num jobs allowed: 10/);
    ok($rows[1] =~/DEBUG 10 jobs running which exceeds 10 not submitting any jobs/);

    # try where queued jobs is set to 72 and running is set 28     
    $logger->clearLog();
    $jobDb->addGetNumberOfJobsInStateResult("cluster",Panfish::JobState->QUEUED(),72);
    $jobDb->addGetNumberOfJobsInStateResult("cluster",Panfish::JobState->RUNNING(),28);
    ok(!defined($submitter->submitJobs("cluster")));
    @rows = $logger->getLogs();
    ok(@rows == 2);
    ok($rows[0] =~/DEBUG Max num jobs allowed: 10/);
    ok($rows[1] =~/DEBUG 100 jobs running which exceeds 10 not submitting any jobs/);
}


# test where there are no jobs to submit

# test where there is one job to submit

# test where there are two jobs to submit with 1 psub file

# test where there are 3 jobs to submit with 2 psub files
