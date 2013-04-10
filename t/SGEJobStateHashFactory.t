#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More tests => 21;
use Panfish::SGEJobStateHashFactory;
use Panfish::MockExecutor;
use Panfish::ForkExecutor;
use Panfish::Logger;
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

# ($logger,$logoutput) = getLogger();
sub getLogger {
    my $logoutput = shift;
    my $logFileHandle = shift;
    open $logFileHandle,'>',\$logoutput;
    my $logger = Panfish::Logger->new();
    $logger->setLevelBasedOnVerbosity(2);
    $logger->setOutput($logFileHandle);

    return $logger;  
}


# test getJobStateHash with qstat returning no results 
{
    my $foo;
    open $foo,'>',\$logoutput;
    my $logger = Panfish::Logger->new();
    $logger->setLevelBasedOnVerbosity(2);
    $logger->setOutput($foo);

    my $config = Panfish::PanfishConfig->new($baseConfig);
    
    my $mockexec = Panfish::MockExecutor->new();
    $mockexec->add_expected_result("qstat -u \"*\" 2>&1","",0,$timeout,undef);

    my $hashFactory = Panfish::SGEJobStateHashFactory->new($config,$logger,$mockexec);
  
    my $jobHash = $hashFactory->getJobStateHash();
    
    ok(keys(%$jobHash) == 0);

    my @rows = split("\n",$logoutput);
    ok(@rows == 1);
    ok($rows[0] =~/DEBUG.*Running.*qstat -u/);
    close($foo);
}


sub getThreeRunningJobs {
return <<ARGUMENTS
job-ID  prior   name       user         state submit/start at     queue                          slots ja-task-ID 
-----------------------------------------------------------------------------------------------------------------
    388 5050.50000 ergatis_bl churas       r     04/10/2013 10:43:19 all.q\@coleslaw.camera.calit2.n     1        
    389 5050.41176 churas_bla churas       r     04/10/2013 10:43:34 panfishblast.q\@coleslaw.camera     1        
    390 5050.00000 churas_pan churas       r     04/10/2013 13:10:49 codonis_shadow.q\@coleslaw.came     1 768
ARGUMENTS
}

# test getJobStateHash with qstat returning 3 running jobs
{
    my $foo;
    open $foo,'>',\$logoutput;
    my $logger = Panfish::Logger->new();
    $logger->setLevelBasedOnVerbosity(2);
    $logger->setOutput($foo);

    my $config = Panfish::PanfishConfig->new($baseConfig);
    
    my $mockexec = Panfish::MockExecutor->new();

    $mockexec->add_expected_result("qstat -u \"*\" 2>&1",getThreeRunningJobs(),0,$timeout,undef);

    my $hashFactory = Panfish::SGEJobStateHashFactory->new($config,$logger,$mockexec);

    my ($jobHash,$error) = $hashFactory->getJobStateHash();
    ok(!defined($error));
    
    ok(keys(%$jobHash) == 3);
    ok($jobHash->{388} eq Panfish::JobState->RUNNING());
    ok($jobHash->{389} eq Panfish::JobState->RUNNING());
    ok($jobHash->{390} eq Panfish::JobState->RUNNING());
 
    my @rows = split("\n",$logoutput);
    ok(@rows == 4);
    ok($rows[0] =~/DEBUG.*Running.*qstat -u/);
    ok($rows[1] =~/DEBUG.*Setting hash 388 => \(r\) -> running/);
    ok($rows[2] =~/DEBUG.*Setting hash 389 => \(r\) -> running/);
    ok($rows[3] =~/DEBUG.*Setting hash 390 => \(r\) -> running/);
    close($foo);
}



sub getOneQueuedJobAndOneHeldJob {
return <<ARGUMENTS
job-ID  prior   name       user         state submit/start at     queue                          slots ja-task-ID 
-----------------------------------------------------------------------------------------------------------------
 673884 50.00486 mintower_b jboss        qw    04/10/2013 14:30:51                                    1 39
 627054 0.00000 mcastro_wo tomcat       hqw   02/08/2013 10:02:36                                    1        
ARGUMENTS
}

{
    my $foo;
    open $foo,'>',\$logoutput;
    my $logger = Panfish::Logger->new();
    $logger->setLevelBasedOnVerbosity(2);
    $logger->setOutput($foo);

    my $config = Panfish::PanfishConfig->new($baseConfig);

    my $mockexec = Panfish::MockExecutor->new();

    $mockexec->add_expected_result("qstat -u \"*\" 2>&1",getOneQueuedJobAndOneHeldJob(),0,$timeout,undef);

    my $hashFactory = Panfish::SGEJobStateHashFactory->new($config,$logger,$mockexec);

    my ($jobHash,$error) = $hashFactory->getJobStateHash();
    ok(!defined($error));

    ok(keys(%$jobHash) == 2);
    ok($jobHash->{673884} eq Panfish::JobState->QUEUED());
    ok($jobHash->{627054} eq Panfish::JobState->QUEUED());

    my @rows = split("\n",$logoutput);
    ok(@rows == 3);
    ok($rows[0] =~/DEBUG.*Running.*qstat -u/);
    ok($rows[1] =~/DEBUG.*Setting hash 673884 => \(qw\) -> queued/);
    ok($rows[2] =~/DEBUG.*Setting hash 627054 => \(hqw\) -> queued/);
    close($foo);
}


