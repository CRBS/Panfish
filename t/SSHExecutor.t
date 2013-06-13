#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib $Bin;

use Test::More tests => 4;
use Panfish::SSHExecutor;

use Mock::Executor;
use Mock::Logger;
use Panfish::Config;
use Panfish::PanfishConfig;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


#
# Test setCluster where Config is not set
#
{
   my $logger = Mock::Logger->new(1);
   my $mockexec = Mock::Executor->new();
   my $exec = Panfish::SSHExecutor->new(undef,$mockexec,$logger);

   ok($exec->setCluster("bob") eq "Config not set...");
}

# 
# Test executeCommandWithRetry where we fail 3 times which is number
# of retries
#

{
   my $logger = Mock::Logger->new(1);
   my $mockexec = Mock::Executor->new();
   $mockexec->add_expected_result("blah","error1","1",undef,undef);
   my $exec = Panfish::SSHExecutor->new(undef,$mockexec,$logger);
   $exec->disableSSH();
   $exec->setStandardInputCommand(undef);
   
   ok($exec->executeCommandWithRetry(3,0,"blah") == 1);
   ok($exec->getOutput() eq "error1");
   ok($exec->getExitCode() == 1);
}

