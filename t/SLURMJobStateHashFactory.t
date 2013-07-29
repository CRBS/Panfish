#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib $Bin;

use Test::More tests => 21;
use Panfish::SLURMJobStateHashFactory;
use Mock::Executor;

use Mock::Logger;
use Panfish::PanfishConfig;
use Panfish::Config;
use Panfish::JobState;
use Panfish::Job;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $timeout = 60; #default timeout

my $baseConfig = Panfish::Config->new();
$baseConfig->setParameter("this.cluster","foo");
$baseConfig->setParameter("foo.stat","squeue -u \"fun\"");

# test getJobStateHash with qstat returning no results 
{

    my $logger = Mock::Logger->new();
    
    my $config = Panfish::PanfishConfig->new($baseConfig);
    
    my $mockexec = Mock::Executor->new();
    $mockexec->add_expected_result("squeue -u \"fun\" 2>&1","",0,$timeout,undef);

    my $hashFactory = Panfish::SLURMJobStateHashFactory->new($config,$logger,$mockexec);
  
    my $jobHash = $hashFactory->getJobStateHash();
    
    ok(keys(%$jobHash) == 0);

    my @rows = $logger->getLogs();
    
    ok(@rows == 1);
    
    ok($rows[0] =~ /DEBUG.*Running squeue -u/); 
}


sub getThreeRunningJobs {
return <<ARGUMENTS
  JOBID   PARTITION     NAME     USER  ST       TIME  NODES NODELIST(REASON)
1037535      serial Na_large      hqj   R    1:22:26      1 c557-302
1037536      serial Na_large      hqj   R    1:22:26      1 c557-401
1037550      serial Na_large      hqj   R    1:22:26      1 c557-604
ARGUMENTS
}

# test getJobStateHash with qstat returning 3 running jobs
{
    my $logger = Mock::Logger->new();
    
    my $config = Panfish::PanfishConfig->new($baseConfig);
    
    my $mockexec = Mock::Executor->new();

    $mockexec->add_expected_result("squeue -u \"fun\" 2>&1",getThreeRunningJobs(),0,$timeout,undef);

    my $hashFactory = Panfish::SLURMJobStateHashFactory->new($config,$logger,$mockexec);

    my ($jobHash,$error) = $hashFactory->getJobStateHash();
    ok(!defined($error));
    
    ok(keys(%$jobHash) == 3);
    ok($jobHash->{1037535} eq Panfish::JobState->RUNNING());
    ok($jobHash->{1037536} eq Panfish::JobState->RUNNING());
    ok($jobHash->{1037550} eq Panfish::JobState->RUNNING());
 
    my @rows = $logger->getLogs();
    
    ok(@rows == 4);
    ok($rows[0] =~/DEBUG Running squeue -u/);
    ok($rows[1] =~/DEBUG.*Setting hash 1037535 => \(R\) -> running/);
    ok($rows[2] =~/DEBUG.*Setting hash 1037536 => \(R\) -> running/);
    ok($rows[3] =~/DEBUG.*Setting hash 1037550 => \(R\) -> running/);
    
}



sub getOneQueuedJobAndOneDoneJob {
return <<ARGUMENTS
  JOBID   PARTITION     NAME     USER  ST       TIME  NODES NODELIST(REASON)
1037051      normal  cu2zno4  mstoica  PD       0:00      2 (Resources)
10      normal  cu2zno4  mstoica  CD       0:00      2 (Resources)
ARGUMENTS
}

{
    
    my $logger = Mock::Logger->new();

    my $config = Panfish::PanfishConfig->new($baseConfig);

    my $mockexec = Mock::Executor->new();

    $mockexec->add_expected_result("squeue -u \"fun\" 2>&1",getOneQueuedJobAndOneDoneJob(),0,$timeout,undef);

    my $hashFactory = Panfish::SLURMJobStateHashFactory->new($config,$logger,$mockexec);

    my ($jobHash,$error) = $hashFactory->getJobStateHash();
    ok(!defined($error));

    ok(keys(%$jobHash) == 2);
    ok($jobHash->{1037051} eq Panfish::JobState->QUEUED());
    ok($jobHash->{10} eq Panfish::JobState->DONE());

    my @rows = $logger->getLogs();
    ok(@rows == 3);
    ok($rows[0] =~/DEBUG.*Running.*squeue -u/);
    ok($rows[1] =~/DEBUG.*Setting hash 1037051 => \(PD\) -> queued/);
    ok($rows[2] =~/DEBUG.*Setting hash 10 => \(CD\) -> done/);
}


