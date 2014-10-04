#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl .t'

#########################


# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib $Bin;

use Test::More tests => 14;

use Mock::Logger;
use Mock::JobDatabase;

use Panfish::FileJobDatabaseJobStateHashFactory;
use Panfish::PanfishConfig;
use Panfish::Config;
use Panfish::JobState;
use Panfish::Job;

#########################

# _convertJobStateToRunningDoneFailed tests
{
  my $logger = Mock::Logger->new();
  my $baseConfig = Panfish::Config->new();
  my $config = Panfish::PanfishConfig->new($baseConfig);
  my $hashFactory = Panfish::FileJobDatabaseJobStateHashFactory->new($config,$logger,undef);
  
  ok($hashFactory->_convertJobStateToRunningDoneFailed(Panfish::JobState->DONE()) eq Panfish::JobState->DONE());
  ok($hashFactory->_convertJobStateToRunningDoneFailed(Panfish::JobState->FAILED()) eq Panfish::JobState->FAILED());
  ok($hashFactory->_convertJobStateToRunningDoneFailed(Panfish::JobState->RUNNING()) eq Panfish::JobState->RUNNING());
  ok($hashFactory->_convertJobStateToRunningDoneFailed("blah") eq Panfish::JobState->RUNNING()); 
  ok($hashFactory->_convertJobStateToRunningDoneFailed(undef) eq Panfish::JobState->RUNNING());
}

# _getNewStateForHashEntry tests
{
  my $logger = Mock::Logger->new();
  my $baseConfig = Panfish::Config->new();
  my $config = Panfish::PanfishConfig->new($baseConfig);
  my $hashFactory = Panfish::FileJobDatabaseJobStateHashFactory->new($config,$logger,undef);
  ok($hashFactory->_getNewStateForHashEntry(undef,"hi") eq "hi");
  
  # done and done
  ok(!defined($hashFactory->_getNewStateForHashEntry(Panfish::JobState->DONE(),
                                                     Panfish::JobState->DONE())));

  # done and failed
  ok($hashFactory->_getNewStateForHashEntry(Panfish::JobState->DONE(),
                                            Panfish::JobState->FAILED()) eq Panfish::JobState->FAILED());

  # done and running
  ok($hashFactory->_getNewStateForHashEntry(Panfish::JobState->DONE(),
                                            Panfish::JobState->RUNNING()) eq Panfish::JobState->RUNNING());
  
  # failed and running
  ok($hashFactory->_getNewStateForHashEntry(Panfish::JobState->FAILED(),
                                            Panfish::JobState->RUNNING()) eq Panfish::JobState->RUNNING());

  # failed and done
  ok(!defined($hashFactory->_getNewStateForHashEntry(Panfish::JobState->FAILED(),
              Panfish::JobState->DONE())));

  # running and anything else
  ok(!defined($hashFactory->_getNewStateForHashEntry(Panfish::JobState->RUNNING(),
              Panfish::JobState->DONE())));

  ok(!defined($hashFactory->_getNewStateForHashEntry(Panfish::JobState->RUNNING(),
              Panfish::JobState->FAILED())));

  ok(!defined($hashFactory->_getNewStateForHashEntry(Panfish::JobState->RUNNING(),
              Panfish::JobState->RUNNING())));

}

# getJobStateHash one cluster no jobs
#{
#  my $logger = Mock::Logger->new();
#  my $baseConfig = Panfish::Config->new();
#  $baseConfig->setParameter("cluster.list","foo");
#  my $config = Panfish::PanfishConfig->new($baseConfig);
#  my $jobDb = Mock::JobDatabase->new(); 
#  my $jobStateHash = Panfish::FileJobDatabaseJobStateHashFactory->new($config,$logger,$jobDb);
#
#  
#}




