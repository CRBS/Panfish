#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib $Bin;

use Test::More tests => 12;
use Panfish::SSHExecutor;

use Mock::Executor;
use Mock::Logger;
use Panfish::Config;
use Panfish::PanfishConfig;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $timeout = 60; #default timeout
my $CLUSTER = "foo";
my $baseConfig = Panfish::Config->new();
$baseConfig->setParameter("this.cluster",$CLUSTER);
$baseConfig->setParameter($CLUSTER.".host","host");
my $config = Panfish::PanfishConfig->new($baseConfig);

#
# Test setCluster where Config is not set
#
{
   my $logger = Mock::Logger->new(1);
   my $mockexec = Mock::Executor->new();
   my $exec = Panfish::SSHExecutor->new(undef,$mockexec,$logger);

   ok($exec->setCluster("bob") eq "Config not set...");
#   my @logs = $logger->getLogs();
#   ok(@logs == 1);
#   ok($logs[0] =~/ERROR Cluster is not set/);
}

# 
# Test executeCommandWithRetry where we fail 3 times which is number
# of retries
#

{
   my $logger = Mock::Logger->new(1);
   my $mockexec = Mock::Executor->new();
   $mockexec->add_expected_result("blah","error1","1",undef,undef);
   $mockexec->add_expected_result("blah","error2","2",undef,undef);
   $mockexec->add_expected_result("blah","error3","3",undef,undef);
   my $exec = Panfish::SSHExecutor->new($config,$mockexec,$logger);
   $exec->disableSSH();
   $exec->setStandardInputCommand(undef);
   
   ok($exec->executeCommandWithRetry(3,0,"blah") == 1);
   my @logs = $logger->getLogs();
   ok(@logs == 5);
   ok($logs[0] =~ /WARN Failed to run command on try # 1 : error3/);
   ok($logs[1] =~ /DEBUG Sleeping 0 seconds and trying again/);
   ok($logs[2] =~ /WARN Failed to run command on try # 2 : error2/);
   ok($logs[3] =~ /DEBUG Sleeping 0 seconds and trying again/);
   ok($logs[4] =~ /WARN Failed to run command on try # 3 : error1/);
}


#
# Test  executeCommandWithRetry where we fail once then succeed
#

{
   my $logger = Mock::Logger->new(1);
   my $mockexec = Mock::Executor->new();
   $mockexec->add_expected_result("blah","good","0",undef,undef);
   $mockexec->add_expected_result("blah","error1","1",undef,undef);
   my $exec = Panfish::SSHExecutor->new($config,$mockexec,$logger);
   $exec->disableSSH();
   $exec->setStandardInputCommand(undef);

   ok($exec->executeCommandWithRetry(2,1,"blah") == 0);
   my @logs = $logger->getLogs();
   ok(@logs == 2);
   ok($logs[0] =~ /WARN Failed to run command on try # 1 : error1/);
   ok($logs[1] =~ /DEBUG Sleeping 1 seconds and trying again/);
}



