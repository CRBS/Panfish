#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib $Bin;

use Test::More tests => 29;
use Panfish::JobHashFactory;
use Mock::Logger;
use Mock::HashKeyGenerator;
use Panfish::Job;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


#
# Test no key generator set
#
{
   my $logger = Mock::Logger->new(1);
   
   my $hashFac = Panfish::JobHashFactory->new(undef,$logger);

   my @jobs;
   $jobs[0] = Panfish::Job->new("cluster","jobid","taskid","jobname",
                              "currentworkingdir","command","state",
                              "modificationtime","commandsfile","psubfile",
                              "realjobid","failreason","batchfactor");

   my ($hash,$error) = $hashFac->getJobHash(\@jobs);
   ok(!defined($hash));
   ok($error eq "Key Generator not defined");

   my @logs = $logger->getLogs();
   ok(@logs == 1);
   ok($logs[0] =~/ERROR Key Generator not defined/);
}

#
# Test no jobs passed in
#
{
   my $logger = Mock::Logger->new(1);

   my $keyGen = Mock::HashKeyGenerator->new();

   my $hashFac = Panfish::JobHashFactory->new($keyGen,$logger);

   my ($hash,$error) = $hashFac->getJobHash();
   ok(!defined($hash));
   ok($error eq "Jobs array not defined");

   my @logs = $logger->getLogs();
   ok(@logs == 1);
   ok($logs[0] =~/ERROR Jobs array not defined/);
}

# 
# Test with empty jobs array
#
{
   my $logger = Mock::Logger->new(1);

   my $keyGen = Mock::HashKeyGenerator->new();

   my $hashFac = Panfish::JobHashFactory->new($keyGen,$logger);

   my @jobs;
  
   my ($hash,$error) = $hashFac->getJobHash(\@jobs);
   ok(defined($hash));
   ok(keys %$hash == 0);
   ok(!defined($error));

   my @logs = $logger->getLogs();
   ok(@logs == 1);
   ok(!defined($logs[0]));
}

#
# Test with undef job in array
#
{
   my $logger = Mock::Logger->new(1);

   my $keyGen = Mock::HashKeyGenerator->new();

   my $hashFac = Panfish::JobHashFactory->new($keyGen,$logger);

   my @jobs;
   $jobs[0] = undef;

   my ($hash,$error) = $hashFac->getJobHash(\@jobs);
   ok(defined($hash));
   ok(keys %$hash == 0);
   ok(!defined($error));

   my @logs = $logger->getLogs();
   ok(@logs == 1);
   ok($logs[0] =~/DEBUG Job # 0 in array is undefined/);
}



#
# Test with one job
#
{
   my $logger = Mock::Logger->new(1);

   my $keyGen = Mock::HashKeyGenerator->new();

   my $hashFac = Panfish::JobHashFactory->new($keyGen,$logger);

   my @jobs;
   $jobs[0] = Panfish::Job->new("cluster","jobid","taskid","jobname",
                              "currentworkingdir","command","state",
                              "modificationtime","commandsfile","psubfile",
                              "realjobid","failreason","batchfactor");


   $keyGen->addGetKeyResult($jobs[0],"1");

   my ($hash,$error) = $hashFac->getJobHash(\@jobs);
   ok(defined($hash));
   ok(!defined($error));

   my $jobArr = $hash->{"1"};
   
   ok(${$jobArr}[0]->equals($jobs[0]));

   ok(!defined($logger->getLogs()));
}

#
# Test with several jobs 
#
{
   my $logger = Mock::Logger->new(1);

   my $keyGen = Mock::HashKeyGenerator->new();

   my $hashFac = Panfish::JobHashFactory->new($keyGen,$logger);

   my @jobs;
   $jobs[0] = Panfish::Job->new("cluster","jobid","taskid","jobname",
                              "currentworkingdir","command","state",
                              "modificationtime","commandsfile","psubfile",
                              "realjobid","failreason","batchfactor");


   $keyGen->addGetKeyResult($jobs[0],"1");

   $jobs[1] = Panfish::Job->new("cluster","2","2","jobname",
                              "currentworkingdir","command","state",
                              "modificationtime","commandsfile","psubfile",
                              "realjobid","failreason","batchfactor");

   $keyGen->addGetKeyResult($jobs[1],"2");

   $jobs[2] = Panfish::Job->new("cluster","2","3","jobname",
                              "currentworkingdir","command","state",
                              "modificationtime","commandsfile","psubfile",
                              "realjobid","failreason","batchfactor");

   $keyGen->addGetKeyResult($jobs[2],"2");

   my ($hash,$error) = $hashFac->getJobHash(\@jobs);
   ok(defined($hash));
   ok(!defined($error));

   my $jobArr = $hash->{"1"};

   ok(@{$jobArr} == 1);
   ok(${$jobArr}[0]->equals($jobs[0]));

   $jobArr = $hash->{"2"};
   ok(@{$jobArr} == 2);

   ok((${$jobArr}[0]->equals($jobs[1]) && ${$jobArr}[1]->equals($jobs[2])) ||
      (${$jobArr}[0]->equals($jobs[2]) && ${$jobArr}[1]->equals($jobs[1])));

   ok(!defined($logger->getLogs()));
}




