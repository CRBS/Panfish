#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib $Bin;

use Test::More tests => 14;
use Panfish::PsubHashKeyGenerator;
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
   
   my $keyGen = Panfish::PsubHashKeyGenerator->new($logger);

   ok(!defined($keyGen->getKey()));

   my @logs = $logger->getLogs();
   ok(@logs == 1);
   ok($logs[0] =~/ERROR Job is not defined/);
}

#
# Test FileUtil is not set
#

{
   my $logger = Mock::Logger->new(1);

   my $keyGen = Panfish::PsubHashKeyGenerator->new($logger);

  my $job = Panfish::Job->new("cluster","jobid","taskid","jobname",
                              "currentworkingdir","command","state",
                              "modificationtime","commandsfile","psubfile",
                              "realjobid","failreason","batchfactor");


   ok(!defined($keyGen->getKey($job)));

   my @logs = $logger->getLogs();
   ok(@logs == 1);
   ok($logs[0] =~/ERROR FileUtil is not defined/);
}


#
# Test with valid psub file, but one that fails FileUtil test
#
{
   my $logger = Mock::Logger->new(1);

   my $fUtil = Mock::FileUtil->new();
   $fUtil->addRunFileTestResult("-f","psubfile",0);
   my $keyGen = Panfish::PsubHashKeyGenerator->new($logger,$fUtil);

   my $job = Panfish::Job->new("cluster","jobid","taskid","jobname",
                              "currentworkingdir","command","state",
                              "modificationtime","commandsfile","psubfile",
                              "realjobid","failreason","batchfactor");

   ok(!defined($keyGen->getKey($job)));
   my @logs = $logger->getLogs();
   ok(@logs == 1);
   ok($logs[0] =~/ERROR psub file psubfile missing for job jobid.taskid/);
}

#
# Test with job where psub file is undefined
#
{
   my $logger = Mock::Logger->new(1);

   my $fUtil = Mock::FileUtil->new();
   $fUtil->addRunFileTestResult("-f","psubfile",0);
   my $keyGen = Panfish::PsubHashKeyGenerator->new($logger,$fUtil);

   my $job = Panfish::Job->new("cluster","jobid","taskid","jobname",
                              "currentworkingdir","command","state",
                              "modificationtime","commandsfile",undef,
                              "realjobid","failreason","batchfactor");

   ok(!defined($keyGen->getKey($job)));
   my @logs = $logger->getLogs();
   ok(@logs == 1);
   ok($logs[0] =~/DEBUG psub file is not defined for job jobid.taskid/);
}



#
# Test with valid psub file
#
{
   my $logger = Mock::Logger->new(1);

   my $fUtil = Mock::FileUtil->new();
   $fUtil->addRunFileTestResult("-f","psubfile",1);

   my $keyGen = Panfish::PsubHashKeyGenerator->new($logger,$fUtil);

   my $job = Panfish::Job->new("cluster","jobid","taskid","jobname",
                              undef,"command","state",
                              "modificationtime","commandsfile","psubfile",
                              "realjobid","failreason","batchfactor");

   ok($keyGen->getKey($job) eq "psubfile");

   ok(!defined($logger->getLogs()));
}


