#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib $Bin;

use Test::More tests => 7;
use Panfish::CurrentWorkingDirHashKeyGenerator;
use Mock::Logger;
use Mock::FileUtil;
use Panfish::Job;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


#
# Test job not defined
#
{
   my $logger = Mock::Logger->new(1);
   
   my $keyGen = Panfish::CurrentWorkingDirHashKeyGenerator->new($logger);

   ok(!defined($keyGen->getKey()));

   my @logs = $logger->getLogs();
   ok(@logs == 1);
   ok($logs[0] =~/ERROR Job is not defined/);
}

#
# Test with valid working dir
#
{
   my $logger = Mock::Logger->new(1);

   my $keyGen = Panfish::CurrentWorkingDirHashKeyGenerator->new($logger);

   my $job = Panfish::Job->new("cluster","jobid","taskid","jobname",
                              "currentworkingdir","command","state",
                              "modificationtime","commandsfile","psubfile",
                              "realjobid","failreason","batchfactor");

   ok($keyGen->getKey($job) eq "currentworkingdir");

   ok(!defined($logger->getLogs()));
}


#
# Test where CurrentWorkingDir is undef
#
{
   my $logger = Mock::Logger->new(1);

   my $keyGen = Panfish::CurrentWorkingDirHashKeyGenerator->new($logger);

   my $job = Panfish::Job->new("cluster","jobid","taskid","jobname",
                              undef,"command","state",
                              "modificationtime","commandsfile","psubfile",
                              "realjobid","failreason","batchfactor");

   ok(!defined($keyGen->getKey($job)));

   ok(!defined($logger->getLogs()));
}


