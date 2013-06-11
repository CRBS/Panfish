#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib $Bin;

use Test::More tests => 13;
use Panfish::PBSJobStateHashFactory;
use Mock::Executor;
use Panfish::ForkExecutor;
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
$baseConfig->setParameter("foo.qstat","qstat");


# test getJobStateHash with qstat returning no results 
{
    my $logger = Mock::Logger->new();

    my $config = Panfish::PanfishConfig->new($baseConfig);
    
    my $mockexec = Mock::Executor->new();
    $mockexec->add_expected_result("qstat","",0,$timeout,undef);

    my $hashFactory = Panfish::PBSJobStateHashFactory->new($config,$logger,$mockexec);
  
    my $jobHash = $hashFactory->getJobStateHash();
    
    ok(keys(%$jobHash) == 0);
    ok(!$logger->getLogs());
}


sub getThreeRunningJobs {
return <<ARGUMENTS
Job id                    Name             User            Time Use S Queue
------------------------- ---------------- --------------- -------- - -----
714018.gordon-fe2         ...F571C9A487DB0 cipres          2299:42: R normal         
714020.gordon-fe2         ...AA634D1B5E013 cipres          2297:31: R normal         
716148.gordon-fe2         ...40E3DA806B838 cipres          2130:58: R normal
ARGUMENTS
}



# test getJobStateHash with qstat returning 3 running jobs
{
    my $logger = Mock::Logger->new();
    my $config = Panfish::PanfishConfig->new($baseConfig);
    
    my $mockexec = Mock::Executor->new();

    $mockexec->add_expected_result("qstat",getThreeRunningJobs(),0,$timeout,undef);

    my $hashFactory = Panfish::PBSJobStateHashFactory->new($config,$logger,$mockexec);

    my ($jobHash,$error) = $hashFactory->getJobStateHash();
    ok(!defined($error));
    
    ok(keys(%$jobHash) == 3);
    ok($jobHash->{714018} eq Panfish::JobState->RUNNING());
    ok($jobHash->{714020} eq Panfish::JobState->RUNNING());
    ok($jobHash->{716148} eq Panfish::JobState->RUNNING());

    ok(!$logger->getLogs()); 
}



sub getOneQueuedJobAndOneHeldJob {
return <<ARGUMENTS
Job id                    Name             User            Time Use S Queue
------------------------- ---------------- --------------- -------- - -----
707735.gordon-fe2         xpc              cherry                 0 H normal         
752034.gordon-fe2         nz51             gridchem               0 Q vsmp 
ARGUMENTS
}

{
    my $logger = Mock::Logger->new();
    my $config = Panfish::PanfishConfig->new($baseConfig);

    my $mockexec = Mock::Executor->new();

    $mockexec->add_expected_result("qstat",getOneQueuedJobAndOneHeldJob(),0,$timeout,undef);

    my $hashFactory = Panfish::PBSJobStateHashFactory->new($config,$logger,$mockexec);

    my ($jobHash,$error) = $hashFactory->getJobStateHash();
    ok(!defined($error));

    ok(keys(%$jobHash) == 2);
    ok($jobHash->{707735} eq Panfish::JobState->QUEUED());
    ok($jobHash->{752034} eq Panfish::JobState->QUEUED());
    ok(!$logger->getLogs());

}


