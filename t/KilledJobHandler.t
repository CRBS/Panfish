#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib $Bin;

use Test::More tests => 22;
use Panfish::KilledJobHandler;
use Panfish::PanfishConfig;
use Panfish::Config;
use Panfish::JobState;
use Panfish::Job;

use Mock::FileUtil;
use Mock::Logger;
use Mock::RemoteIO;
use Mock::JobDatabase;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $timeout = 60; #default timeout

# test removeKilledJobs where cluster not set  
{
    my $logger = Mock::Logger->new();
    my $fUtil = Mock::FileUtil->new();
    my $jobDb = Mock::JobDatabase->new();
    my $remoteIO = Mock::RemoteIO->new();
    my $killer = Panfish::KilledJobHandler->new($jobDb,$logger,$fUtil,$remoteIO);

    ok(defined($killer));

    ok($killer->removeKilledJobs() eq "Cluster is not set");
}

# test removeKilledJobs where there are no jobs to be killed
{
    my $logger = Mock::Logger->new();
    my $fUtil = Mock::FileUtil->new();
    my $jobDb = Mock::JobDatabase->new();
    my $remoteIO = Mock::RemoteIO->new();
    my @emptyArr;
    my $killState = Panfish::JobState->KILL();
    $jobDb->addGetJobsByClusterAndStateResult("foo",$killState,\@emptyArr);
 
    my $killer = Panfish::KilledJobHandler->new($jobDb,$logger,$fUtil,$remoteIO);

    ok(!defined($killer->removeKilledJobs("foo")));
    
    my @logs = $logger->getLogs();
    ok(@logs == 1);
    ok($logs[0]=~/DEBUG No jobs in $killState state on foo/);
}


# test removeKilledJobs where there is 1 job to be killed but it is not in the database
{
    my $logger = Mock::Logger->new();
    my $fUtil = Mock::FileUtil->new();
    my $jobDb = Mock::JobDatabase->new();
    my $remoteIO = Mock::RemoteIO->new();
    my @oneJob;
    my $killState = Panfish::JobState->KILL();
    $oneJob[0] = Panfish::Job->new("foo","1","1");
    $jobDb->addGetJobsByClusterAndStateResult("foo",$killState,\@oneJob);
 
    my $killer = Panfish::KilledJobHandler->new($jobDb,$logger,$fUtil,$remoteIO);

    ok(!defined($killer->removeKilledJobs("foo")));
    
    my @logs = $logger->getLogs();
    ok(@logs == 3);
    ok($logs[0]=~/DEBUG Found 1 job\(s\) in $killState state on foo/);
    ok($logs[1]=~/DEBUG Job to be killed not found: 1.1 deleting kill file and moving on/);
    ok($logs[2]=~/INFO Handled 1 job\(s\) on foo/);
}

# test removeKilledJobs where there is 2 jobs to be killed but they are in done or failed states
{
    my $logger = Mock::Logger->new();
    my $fUtil = Mock::FileUtil->new();
    my $jobDb = Mock::JobDatabase->new();
    my $remoteIO = Mock::RemoteIO->new();
    my @twoJobs;

    my $killState = Panfish::JobState->KILL();
    my $doneState = Panfish::JobState->DONE();
    my $failedState = Panfish::JobState->FAILED();

    $twoJobs[0] = Panfish::Job->new("foo","1","1");
    $twoJobs[1] = Panfish::Job->new("foo","3","4");
    $jobDb->addGetJobsByClusterAndStateResult("foo",$killState,\@twoJobs);

    $jobDb->addGetJobByClusterAndIdResult("foo","1","1",
                                          Panfish::Job->new("foo","1","1",
                                                            "name","/foo",
                                                            "cmd",$doneState));
    $jobDb->addGetJobByClusterAndIdResult("foo","3","4",
                                          Panfish::Job->new("foo","3","4",
                                                            "name","/foo",
                                                            "cmd",$failedState));
 
    my $killer = Panfish::KilledJobHandler->new($jobDb,$logger,$fUtil,$remoteIO);

    ok(!defined($killer->removeKilledJobs("foo")));
    
    my @logs = $logger->getLogs();
    ok(@logs == 4);
    ok($logs[0]=~/DEBUG Found 2 job\(s\) in $killState state on foo/);
    ok($logs[1]=~/DEBUG Job 1.1 in state that requires no action for deletion/);
    ok($logs[2]=~/DEBUG Job 3.4 in state that requires no action for deletion/);
    ok($logs[3]=~/INFO Handled 2 job\(s\) on foo/);
}

# test removeKilledJobs where there are 2 jobs in submitted state to be killed
{
    my $logger = Mock::Logger->new();
    my $fUtil = Mock::FileUtil->new();
    my $jobDb = Mock::JobDatabase->new();
    my $remoteIO = Mock::RemoteIO->new();
    my @twoJobs;
    
    my $failedState = Panfish::JobState->FAILED();
    my $killState = Panfish::JobState->KILL();
    my $submittedState = Panfish::JobState->SUBMITTED();

    $twoJobs[0] = Panfish::Job->new("foo","1","1");
    $twoJobs[1] = Panfish::Job->new("foo","3","4");
    $jobDb->addGetJobsByClusterAndStateResult("foo",$killState,\@twoJobs);

    $jobDb->addGetJobByClusterAndIdResult("foo","1","1",
                                          Panfish::Job->new("foo","1","1",
                                                            "name","/foo",
                                                            "cmd",$submittedState));
    $jobDb->addGetJobByClusterAndIdResult("foo","3","4",
                                          Panfish::Job->new("foo","3","4",
                                                            "name","/foo",
                                                            "cmd",$submittedState));

    $jobDb->addUpdateResult($twoJobs[0],undef);
    $jobDb->addUpdateResult($twoJobs[1],"someerror");

    my $killer = Panfish::KilledJobHandler->new($jobDb,$logger,$fUtil,$remoteIO);

    ok(!defined($killer->removeKilledJobs("foo")));

    my @logs = $logger->getLogs();
    ok(@logs == 3);
    ok($logs[0]=~/DEBUG Found 2 job\(s\) in $killState state on foo/);
    ok($logs[1]=~/WARN Unable to update job 3.4 to $failedState/);
    ok($logs[2]=~/INFO Handled 2 job\(s\) on foo/);
}
# test removeKilledJobs where there is a batched job to be killed and no other
# jobs are in batched state that need reverting back to submitted state
{
    my $logger = Mock::Logger->new();
    my $fUtil = Mock::FileUtil->new();
    my $jobDb = Mock::JobDatabase->new();
    my $remoteIO = Mock::RemoteIO->new();
    my @oneJob;
    
    my $failedState = Panfish::JobState->FAILED();
    my $killState = Panfish::JobState->KILL();
    my $batchedState = Panfish::JobState->BATCHED();

    $oneJob[0] = Panfish::Job->new("foo","1","1");
    $jobDb->addGetJobsByClusterAndStateResult("foo",$killState,\@oneJob);

    $jobDb->addGetJobByClusterAndIdResult("foo","1","1",
                                          Panfish::Job->new("foo","1","1",
                                                            "name","/foo",
                                                            "cmd",$batchedState,123,"/x/foo.q/cmdsfile.1.1",
                                                            "/x/foo.q/psubfile.1.1"));

    $jobDb->addUpdateResult($oneJob[0],undef);

    $fUtil->addDeleteFileResult("/x/foo.q/cmdsfile.1.1",1);
    $fUtil->addDeleteFileResult("/x/foo.q/psubfile.1.1",0);

    my $killer = Panfish::KilledJobHandler->new($jobDb,$logger,$fUtil,$remoteIO);

    ok(!defined($killer->removeKilledJobs("foo")));

    my @logs = $logger->getLogs();
    ok(@logs == 4);
    ok($logs[0]=~/DEBUG Found 1 job\(s\) in $killState state on foo/);
    ok($logs[1]=~/ERROR Error deleting \/x\/foo.q\/psubfile.1.1/);
    ok($logs[2]=~/DEBUG No jobs in batched to examine for possible moving to submitted state/);
    ok($logs[3]=~/INFO Handled 1 job\(s\) on foo/);
}

# test removeKilledJobs where there is a batched job to be killed and two
# other jobs are in batched state that need reverting back to submitted state

# test removeKilledJobs where there is a batched job to be killed and two
# other jobs are in batched state that need reverting back to submitted state
# that are also listed to be killed


# test removeKilledJobs where there is a batchedandchummed job to be killed

# test removeKilledJobs where there is a running job to be killed

# test removeKilledJobs where several jobs in batchedandchummed/running state some sharing
# same .commands file need to be killed

