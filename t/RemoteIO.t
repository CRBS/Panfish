#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib $Bin;

use Test::More tests => 11;
use Panfish::RemoteIO;
use Mock::SSHExecutor;
use Mock::Executor;
use Mock::Logger;
use Mock::FileUtil;
use Panfish::Config;
use Panfish::PanfishConfig;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

# config used by the tests below
my $config = Panfish::Config->new();
$config->setParameter("foo.io.retry.count","1");
$config->setParameter("foo.io.retry.sleep","2");
$config->setParameter("foo.io.timeout","3");
$config->setParameter("foo.host","thehost");
$config->setParameter("foo.basedir","/basey");
$config->setParameter("foo.panfishsetup","panfishsetup");
my $pConfig = Panfish::PanfishConfig->new($config);




# test directUpload with valid call
{
    my $logger = Mock::Logger->new();
    my $sshexec = Mock::SSHExecutor->new();
    my $fUtil = Mock::FileUtil->new();

    $fUtil->addGetDirnameResult("/x/remotefoo","/x");

    $sshexec->addExecuteCommandWithRetryResult(1,2,"/bin/mkdir -p /x",3,undef,0);

    $sshexec->addExecuteCommandWithRetryResult(1,2,"/usr/bin/rsync -rtpz  --stats --timeout=3 -e \"/usr/bin/ssh\" /foo thehost:/x/remotefoo 2>&1",3,undef,0);

    my $remote = Panfish::RemoteIO->new($pConfig,$sshexec,$logger,$fUtil);

    ok(!defined($remote->directUpload("/foo","/x/remotefoo","foo",undef)));

    my @logs = $logger->getLogs();
    ok(@logs == 2);
    ok($logs[0] =~/DEBUG Uploading \/foo to foo:\/x\/remotefoo\/./);
    ok($logs[1] =~/DEBUG Running \/usr\/bin\/rsync -rtpz  --stats --timeout=3 -e "\/usr\/bin\/ssh" \/foo thehost:\/x\/remotefoo 2>&1/);
}

# test directUpload with failed mkdir
{
    my $logger = Mock::Logger->new();
    my $sshexec = Mock::SSHExecutor->new();
    my $fUtil = Mock::FileUtil->new();

    $fUtil->addGetDirnameResult("/x/remotefoo","/x");

    $sshexec->addExecuteCommandWithRetryResult(1,2,"/bin/mkdir -p /x",3,undef,1);

    $sshexec->addExecuteCommandWithRetryResult(1,2,"/usr/bin/rsync -rtpz  --stats --timeout=3 -e \"/usr/bin/ssh\" /foo thehost:/x/remotefoo 2>&1",3,undef,0);

    my $remote = Panfish::RemoteIO->new($pConfig,$sshexec,$logger,$fUtil);

    ok($remote->directUpload("/foo","/x/remotefoo","foo",undef) eq "Unable to create /x on foo");

    my @logs = $logger->getLogs();
    ok(@logs == 1);
    ok($logs[0] =~/DEBUG Uploading \/foo to foo:\/x\/remotefoo\/./);
}

# test directUpload with failed rsync
{
    my $logger = Mock::Logger->new();
    my $sshexec = Mock::SSHExecutor->new();
    my $fUtil = Mock::FileUtil->new();

    $fUtil->addGetDirnameResult("/x/remotefoo","/x");

    $sshexec->addExecuteCommandWithRetryResult(1,2,"/bin/mkdir -p /x",3,undef,0);

    $sshexec->addExecuteCommandWithRetryResult(1,2,"/usr/bin/rsync -rtpz  --stats --timeout=3 -e \"/usr/bin/ssh\" /foo thehost:/x/remotefoo 2>&1",3,undef,1);

    my $remote = Panfish::RemoteIO->new($pConfig,$sshexec,$logger,$fUtil);

    ok($remote->directUpload("/foo","/x/remotefoo","foo",undef) eq "Unable to upload after 1 tries.  Giving up");

    my @logs = $logger->getLogs();
    ok(@logs == 2);
    ok($logs[0] =~/DEBUG Uploading \/foo to foo:\/x\/remotefoo\/./);
    ok($logs[1] =~/DEBUG Running \/usr\/bin\/rsync -rtpz  --stats --timeout=3 -e "\/usr\/bin\/ssh" \/foo thehost:\/x\/remotefoo 2>&1/);
    
}

# test delete with valid call

# test delete with failed call

# test deleteAndUpload with valid call

# test deleteAndUpload where delete fails

# test deleteAndUpload where upload fails

# test upload with valid call

# test upload where mkdir fails

# test upload where rsync fails

# test download with valid call

# test download where rsync fails

# test getDirectorySize with valid call

# test getDirectorySize with failed call

# test exists invalid path

# test exists invalid cluster

# test exists where remote exists command fails

# test exists with valid call





