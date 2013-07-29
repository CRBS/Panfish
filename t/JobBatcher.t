#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib $Bin;

use Test::More tests => 3;
use Panfish::JobBatcher;
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
$baseConfig->setParameter($CLUSTER.".basedir","base");
my $config = Panfish::PanfishConfig->new($baseConfig);

#
# Test cluster not defined
#
{
   my $logger = Mock::Logger->new(1);
   
   my $batcher = Panfish::JobBatcher->new($config,undef,$logger,undef,undef,undef);
   ok($batcher->batchJobs() eq "Cluster is not set");

   my @logs = $logger->getLogs();
   ok(@logs == 1);
   ok($logs[0] =~/ERROR Cluster is not set/);
}

#
# Test where there are no jobs to batch
#

#
# Test where a job is not batchable cause cause Override timeout is not set
#

#
# Test where a job is not batchable cause there are too few jobs for immediate batching and
# the override timeout has not been met
#



#
# Test where we are unable to open job template directory for a cluster
#



