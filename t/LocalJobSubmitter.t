#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib $Bin;

use Test::More tests => 9;
use Panfish::LocalJobSubmitter;
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

# test submitJobs cluster not set  
{
    my $logger = Mock::Logger->new();
    my $hashFac = Mock::JobHashFactory->new();
    my $pConfig = Panfish::PanfishConfig->new();
    my $jobDb = Mock::JobDatabase->new();
    my $submitCommand = "";
    my $commandParser = "";
    my $pathSorter = "";
    
    my $submitter = Panfish::LocalJobSubmitter->new($pConfig,$jobDb,$hashFac,$submitCommand,$commandParser,$pathSorter,$logger);
 
    ok($submitter->submitJobs(undef) eq "Cluster is not set");
    ok($submitter->submitJobs("") eq "Cluster is not set");

    # test submitJobs where cluster specified is not the local cluster
    ok(!defined($submitter->submitJobs("foo")));
    my $config = Panfish::Config->new();
    $config->setParameter($pConfig->{THIS_CLUSTER},"gee");
    $pConfig->setConfig($config);
    ok(!defined($submitter->submitJobs("yo")));	

   
    my @rows = $logger->getLogs();
    ok(@rows == 4);
    ok($rows[0] =~/ERROR Cluster is not set/);
    ok($rows[1] =~/ERROR Cluster is not set/);
    ok($rows[2] =~/ERROR foo is not considered a local cluster/);
    ok($rows[3] =~/ERROR yo is not considered a local cluster/);
}


# test submitJobs where Number of jobs in queued/running state exceed max running jobs already

    # try where queued jobs is set to 10 and running is set 0
    
    # try where queued jobs is set to 0 and running is set 10

    # try where queued jobs is set to 7 and running is set 3

    # try where queued jobs is set to 72 and running is set 28     

# test where there are no jobs to submit

# test where there is one job to submit

# test where there are two jobs to submit with 1 psub file

# test where there are 3 jobs to submit with 2 psub files
