#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl .t'

#########################


# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib $Bin;

use Test::More tests => 11;
use Panfish::FileReaderWriterImpl;
use Mock::FileReaderWriter;
use Panfish::FileUtil;
use Mock::FileUtil;
use Panfish::FileJobDatabase;
use Panfish::Logger;
use Mock::Logger;
use Panfish::Config;
use Panfish::PanfishConfig;
use Panfish::ConfigFromFileFactory;
use Panfish::JobToClusterAssigner;
use Panfish::JobState;
use Panfish::Job;

#########################


# test _getHashOfOpenSlotsPerCluster 
{
  my $logger = Mock::Logger->new();
  my $testdir = $Bin."/JobToClusterAssigner";
  my $fUtil = Panfish::FileUtil->new($logger);
  my $readerWriter = Panfish::FileReaderWriterImpl->new($logger);
  my $jobDb = Panfish::FileJobDatabase->new($readerWriter,$testdir,
                                            $fUtil,$logger);
  $jobDb->initializeDatabase("foo");
  $jobDb->initializeDatabase("bar");
  my $config = Panfish::PanfishConfig->new();
  my $assigner = Panfish::JobToClusterAssigner->new($config, $jobDb,
                                                    $logger);
  my $ht = $assigner->_getHashOfOpenSlotsPerCluster();
  ok(keys %$ht == 0);
  my $con = Panfish::Config->new();
  $con->setParameter($config->{CLUSTER_LIST}, "foo,bar");
  $con->setParameter("foo.".$config->{MAX_NUM_QUEUED_JOBS},2);
  $config->setConfig($con);

  $ht = $assigner->_getHashOfOpenSlotsPerCluster();
  ok($ht->{"foo"} == 2);
  ok($ht->{"bar"} == $assigner->{DEFAULT_MAX_QUEUED_JOBS});
  
  # lets add some jobs to foo
  $fUtil->touch($testdir."/foo/".Panfish::JobState->QUEUED()."/123");
  $ht = $assigner->_getHashOfOpenSlotsPerCluster();
  ok($ht->{"foo"} == 1, "got ". $ht->{"foo"});
  ok($ht->{"bar"} == $assigner->{DEFAULT_MAX_QUEUED_JOBS});

  $fUtil->touch($testdir."/foo/".Panfish::JobState->QUEUED()."/111");
  $ht = $assigner->_getHashOfOpenSlotsPerCluster();
  ok($ht->{"foo"} == 0);
  ok($ht->{"bar"} == $assigner->{DEFAULT_MAX_QUEUED_JOBS});

  $fUtil->touch($testdir."/foo/".Panfish::JobState->RUNNING()."/11");
  $ht = $assigner->_getHashOfOpenSlotsPerCluster();
  ok($ht->{"foo"} == 0);
  ok($ht->{"bar"} == $assigner->{DEFAULT_MAX_QUEUED_JOBS});




}

# test assignJobs no jobs to assign 
{
  my $logger = Mock::Logger->new();
  my $testdir = $Bin."/JobToClusterAssigner";
  my $fUtil = Panfish::FileUtil->new($logger);
  my $readerWriter = Panfish::FileReaderWriterImpl->new($logger);
  my $jobDb = Panfish::FileJobDatabase->new($readerWriter,$testdir,
                                            $fUtil,$logger);
  ok($jobDb->initializeUnassignedDatabase() == 1);

  my $config = Panfish::PanfishConfig->new();

  # Test we get zero on an empty database
  my $assigner = Panfish::JobToClusterAssigner->new($config, $jobDb,
                                                    $logger);
  ok($assigner->assignJobs() == 0);
 
  $fUtil->recursiveRemoveDir($testdir);
}
