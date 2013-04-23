#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib $Bin;

use Test::More tests => 11;
use Panfish::PsubIdHashKeyGenerator;
use Mock::HashKeyGenerator;
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
   
   my $keyGen = Panfish::PsubIdHashKeyGenerator->new($logger);

   ok(!defined($keyGen->getKey()));

   my @logs = $logger->getLogs();
   ok(@logs == 1);
   ok($logs[0] =~/ERROR Job is not defined/);
}

#
# Test KeyGenerator is not set
#

{
   my $logger = Mock::Logger->new(1);

   my $keyGen = Panfish::PsubIdHashKeyGenerator->new($logger);

  my $job = Panfish::Job->new("cluster","jobid","taskid","jobname",
                              "currentworkingdir","command","state",
                              "modificationtime","commandsfile","psubfile",
                              "realjobid","failreason","batchfactor");


   ok(!defined($keyGen->getKey($job)));

   my @logs = $logger->getLogs();
   ok(@logs == 1);
   ok($logs[0] =~/ERROR PsubHashKeyGenerator is not defined/);
}


#
# Test underlying keygen kicks back undefined for key
#
{
   my $logger = Mock::Logger->new(1);

   my $mockGen = Mock::HashKeyGenerator->new();


   my $keyGen = Panfish::PsubIdHashKeyGenerator->new($logger,$mockGen);

   my $job = Panfish::Job->new("cluster","jobid","taskid","jobname",
                              "currentworkingdir","command","state",
                              "modificationtime","commandsfile","psubfile",
                              "realjobid","failreason","batchfactor");

   $mockGen->addGetKeyResult($job,undef);

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

   my $mockGen = Mock::HashKeyGenerator->new();
   

   my $keyGen = Panfish::PsubIdHashKeyGenerator->new($logger,$mockGen);

   my $job = Panfish::Job->new("cluster","jobid","taskid","jobname",
                              undef,"command","state",
                              "modificationtime","commandsfile","/home/foo/blat/123.4.psub",
                              "realjobid","failreason","batchfactor");

   $mockGen->addGetKeyResult($job,"/home/foo/blat/123.4.psub");

   ok($keyGen->getKey($job) eq "123.4");

   ok(!defined($logger->getLogs()));
}


