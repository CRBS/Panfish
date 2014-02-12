#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More tests => 134;
use Panfish::PanfishConfig;
use Panfish::Config;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

# test various get methods with no config set
{
   my $config = Panfish::PanfishConfig->new();
   ok($config->getThisCluster() eq "");
   ok($config->getPanfishSubmit() eq "/".$config->{PANFISH_SUBMIT});

}


# test isClusterPartOfThisCluster 
{
   my $config = Panfish::PanfishConfig->new();
   
   # config not set
   ok($config->isClusterPartOfThisCluster("ha") == 0);

   my $con = Panfish::Config->new();

   $con->setParameter($config->{THIS_CLUSTER},"");
   $config->setConfig($con);

   # this cluster is set to empty string   
   ok($config->isClusterPartOfThisCluster("") == 0);
   ok($config->isClusterPartOfThisCluster(" ") == 0);
   ok($config->isClusterPartOfThisCluster("foo") == 0);
   ok($config->isClusterPartOfThisCluster("ha") == 0);

   # this cluster set to single cluster
   $con->setParameter($config->{THIS_CLUSTER},"beer");
   $con->setParameter("foo.".$config->{HOST},"bla\@somehost.com");
   $con->setParameter("beer.".$config->{HOST},"bla\@somehost.com");
   $con->setParameter("cheese.".$config->{HOST},"");
   ok($config->isClusterPartOfThisCluster("") == 0);
   ok($config->isClusterPartOfThisCluster(" ") == 0);
   ok($config->isClusterPartOfThisCluster("foo") == 0);
   ok($config->isClusterPartOfThisCluster("beer") == 1);
   ok($config->isClusterPartOfThisCluster("some,beer,yo") == 1);
   ok($config->isClusterPartOfThisCluster("cheese") == 1);
}

# test getClusterListAsArray with no config set and with empty cluster list
{
   
   my $config = Panfish::PanfishConfig->new();
   my ($skippedClusters,@cArray) = $config->getClusterListAsArray();
   ok(!@cArray);
   ok(!defined($skippedClusters));

   ($skippedClusters,@cArray) = $config->getClusterListAsArray(undef,1);
   ok(!@cArray);
   ok(!defined($skippedClusters));

   my $con = Panfish::Config->new();
   $con->setParameter("cluster.list","");
   $config = Panfish::PanfishConfig->new($con);

   ($skippedClusters,@cArray) = $config->getClusterListAsArray();
   ok(!@cArray);
   ok(!defined($skippedClusters));

   ($skippedClusters,@cArray) = $config->getClusterListAsArray(undef,1);
   ok(!@cArray);
   ok(!defined($skippedClusters));
}

# test getClusterListAsArray with cluster list undef and skipCheck undef and set to 1 and 1 node in cluster
{
   my $con = Panfish::Config->new();
   $con->setParameter("cluster.list","one");
   my $config = Panfish::PanfishConfig->new($con);

   my ($skippedClusters,@cArray) = $config->getClusterListAsArray();
   ok(@cArray == 1);
   ok($cArray[0] eq "one");
   ok(!defined($skippedClusters));
   ($skippedClusters,@cArray) = $config->getClusterListAsArray(undef,1);

   ok(@cArray == 1);
   ok($cArray[0] eq "one");
   ok(!defined($skippedClusters));
}


# test getClusterListAsArray with cluster list undef and skipCheck undef and set to 1 and 3 nodes in cluster
{
   my $con = Panfish::Config->new();
   $con->setParameter("cluster.list","one,two,three");
   my $config = Panfish::PanfishConfig->new($con);
   
   my ($skippedClusters,@cArray) = $config->getClusterListAsArray();

   ok(@cArray == 3);
   ok($cArray[0] eq "one");
   ok($cArray[1] eq "two");
   ok($cArray[2] eq "three");
   ok(!defined($skippedClusters));
   ($skippedClusters,@cArray) = $config->getClusterListAsArray(undef,1);

   ok(@cArray == 3);
   ok($cArray[0] eq "one");
   ok($cArray[1] eq "two");
   ok($cArray[2] eq "three");
   ok(!defined($skippedClusters));
}  

# test getClusterListAsArray with cluster list set to a single cluster not in list and set skipCheck undef and 1
{
   my $con = Panfish::Config->new();
   $con->setParameter("cluster.list","one");
   my $config = Panfish::PanfishConfig->new($con);

   my ($skippedClusters,@cArray) = $config->getClusterListAsArray("two");
   ok(@cArray == 0);
   ok($skippedClusters eq "two");
   ($skippedClusters,@cArray) = $config->getClusterListAsArray("two",1);

   ok(@cArray == 1);
   ok($cArray[0] eq "two");
   ok(!defined($skippedClusters));

   $con = Panfish::Config->new();
   $con->setParameter("cluster.list","one,two,three");
   $config = Panfish::PanfishConfig->new($con);
   
   ($skippedClusters,@cArray) = $config->getClusterListAsArray("four");

   ok(@cArray == 0);
   ok($skippedClusters  eq "four");
   ($skippedClusters,@cArray) = $config->getClusterListAsArray("four",1);

   ok(@cArray == 1);
   ok($cArray[0] eq "four");
   ok(!defined($skippedClusters));
}


# test getClusterListAsArray with cluster list set to a single in list and set skipCheck undef and 1
{
   my $con = Panfish::Config->new();
   $con->setParameter("cluster.list","one");
   my $config = Panfish::PanfishConfig->new($con);

   my ($skippedClusters,@cArray) = $config->getClusterListAsArray("one");
   ok(@cArray == 1);
   ok($cArray[0] eq "one");
   ok(!defined($skippedClusters));
   ($skippedClusters,@cArray) = $config->getClusterListAsArray("one",1);

   ok(@cArray == 1);
   ok($cArray[0] eq "one");
   ok(!defined($skippedClusters));
}


# test getClusterListAsArray with cluster list set to a multiple clusters in list and set skipCheck undef and 1
{
   my $con = Panfish::Config->new();
   $con->setParameter("cluster.list","one,two,three");
   my $config = Panfish::PanfishConfig->new($con);

   my ($skippedClusters,@cArray) = $config->getClusterListAsArray("one,two,three");

   ok(@cArray == 3);
   ok($cArray[0] eq "one");
   ok($cArray[1] eq "two");
   ok($cArray[2] eq "three");
   ok(!defined($skippedClusters));
   ($skippedClusters,@cArray) = $config->getClusterListAsArray("one,two,three",1);

   ok(@cArray == 3);
   ok($cArray[0] eq "one");
   ok($cArray[1] eq "two");
   ok($cArray[2] eq "three");
   ok(!defined($skippedClusters));
}

# test getClusterListAsArray with cluster list set to a multiple clusters with some in list and some not and set skipCheck undef and 1
{
   my $con = Panfish::Config->new();
   $con->setParameter("cluster.list","one,two,three");
   my $config = Panfish::PanfishConfig->new($con);

   my ($skippedClusters,@cArray) = $config->getClusterListAsArray("two,yo,three,bye");

   ok(@cArray == 2);
   ok($cArray[0] eq "two");
   ok($cArray[1] eq "three");
   ok($skippedClusters eq "yo,bye");
   ($skippedClusters,@cArray) = $config->getClusterListAsArray("two,yo,three,bye",1);

   ok(@cArray == 4);
   ok($cArray[0] eq "two");
   ok($cArray[1] eq "yo");
   ok($cArray[2] eq "three");
   ok($cArray[3] eq "bye");
   ok(!defined($skippedClusters));
}

# test getConfigForCluster with no cluster set and no config for that matter
{
   my $config = Panfish::PanfishConfig->new();
   my @cArray = $config->getConfigForCluster();
   ok(!@cArray);
}


# test getConfigForCluster with fields not set but cluster set
{
   my $config = Panfish::PanfishConfig->new();
   my @cArray = $config->getConfigForCluster("foo");
   ok(@cArray == 13);
   ok($cArray[0] eq $config->{THIS_CLUSTER}."=foo");
   ok($cArray[1] eq $config->{CLUSTER_LIST}."=foo");
   ok($cArray[2] eq "foo.".$config->{ENGINE}."=");
   ok($cArray[3] eq "foo.".$config->{BASE_DIR}."=");
   ok($cArray[4] eq "foo.".$config->{DATABASE_DIR}."=");
   ok($cArray[5] eq "foo.".$config->{SUBMIT}."=");
   ok($cArray[6] eq "foo.".$config->{STAT}."=");
   ok($cArray[7] eq "foo.".$config->{BIN_DIR}."=");
   ok($cArray[8] eq "foo.".$config->{MAX_NUM_RUNNING_JOBS}."=");
   ok($cArray[9] eq "foo.".$config->{PANFISH_SLEEP}."=");
   ok($cArray[10] eq "foo.".$config->{SCRATCH}."=");
   ok($cArray[11] eq "foo.".$config->{PANFISH_VERBOSITY}."=");
   ok($cArray[12] eq "foo.".$config->{PANFISHSUBMIT_VERBOSITY}."=");
}

# test getConfigForCluster where all fields have values
{
   my $con = Panfish::Config->new();
   my $tconfig = Panfish::PanfishConfig->new();
   $con->setParameter("foo.".$tconfig->{ENGINE},"1");
   $con->setParameter("foo.".$tconfig->{BASE_DIR},"2");
   $con->setParameter("foo.".$tconfig->{DATABASE_DIR},"3");
   $con->setParameter("foo.".$tconfig->{SUBMIT},"4");
   $con->setParameter("foo.".$tconfig->{STAT},"5");
   $con->setParameter("foo.".$tconfig->{BIN_DIR},"6");
   $con->setParameter("foo.".$tconfig->{MAX_NUM_RUNNING_JOBS},"7");
   $con->setParameter("foo.".$tconfig->{PANFISH_SLEEP},"8");
   $con->setParameter("foo.".$tconfig->{SCRATCH},"9");
   $con->setParameter("foo.".$tconfig->{PANFISH_VERBOSITY},"10");
   $con->setParameter("foo.".$tconfig->{PANFISHSUBMIT_VERBOSITY},"11");

   # set an alias cluster
   $con->setParameter("bar.".$tconfig->{ALIAS_TO},"foo");

   my $config = Panfish::PanfishConfig->new($con);
   my @cArray = $config->getConfigForCluster("foo");
   ok(@cArray == 13);
   ok($cArray[0] eq $config->{THIS_CLUSTER}."=foo");
   ok($cArray[1] eq $config->{CLUSTER_LIST}."=foo");
   ok($cArray[2] eq "foo.".$config->{ENGINE}."=1");
   ok($cArray[3] eq "foo.".$config->{BASE_DIR}."=2");
   ok($cArray[4] eq "foo.".$config->{DATABASE_DIR}."=3");
   ok($cArray[5] eq "foo.".$config->{SUBMIT}."=4");
   ok($cArray[6] eq "foo.".$config->{STAT}."=5");
   ok($cArray[7] eq "foo.".$config->{BIN_DIR}."=6");
   ok($cArray[8] eq "foo.".$config->{MAX_NUM_RUNNING_JOBS}."=7");
   ok($cArray[9] eq "foo.".$config->{PANFISH_SLEEP}."=8");
   ok($cArray[10] eq "foo.".$config->{SCRATCH}."=9");
   ok($cArray[11] eq "foo.".$config->{PANFISH_VERBOSITY}."=10");
   ok($cArray[12] eq "foo.".$config->{PANFISHSUBMIT_VERBOSITY}."=11");

   # test alias cluster
   @cArray = $config->getConfigForCluster("bar");
   ok(@cArray == 13);
   ok($cArray[0] eq $config->{THIS_CLUSTER}."=bar");
   ok($cArray[1] eq $config->{CLUSTER_LIST}."=bar");
   ok($cArray[2] eq "bar.".$config->{ENGINE}."=1");
   ok($cArray[3] eq "bar.".$config->{BASE_DIR}."=2");
   ok($cArray[4] eq "bar.".$config->{DATABASE_DIR}."=3");
   ok($cArray[5] eq "bar.".$config->{SUBMIT}."=4");
   ok($cArray[6] eq "bar.".$config->{STAT}."=5");
   ok($cArray[7] eq "bar.".$config->{BIN_DIR}."=6");
   ok($cArray[8] eq "bar.".$config->{MAX_NUM_RUNNING_JOBS}."=7");
   ok($cArray[9] eq "bar.".$config->{PANFISH_SLEEP}."=8");
   ok($cArray[10] eq "bar.".$config->{SCRATCH}."=9");
   ok($cArray[11] eq "bar.".$config->{PANFISH_VERBOSITY}."=10");
   ok($cArray[12] eq "bar.".$config->{PANFISHSUBMIT_VERBOSITY}."=11");

   # test update with new config
   my $newConfig = Panfish::Config->new();
   $newConfig->setParameter("foo.".$tconfig->{MAX_NUM_RUNNING_JOBS},"7.1");
   $config->updateWithConfig($newConfig);

   @cArray = $config->getConfigForCluster("foo");
   ok(@cArray == 13);
   ok($cArray[0] eq $config->{THIS_CLUSTER}."=foo");
   ok($cArray[1] eq $config->{CLUSTER_LIST}."=foo");
   ok($cArray[2] eq "foo.".$config->{ENGINE}."=1");
   ok($cArray[3] eq "foo.".$config->{BASE_DIR}."=2");
   ok($cArray[4] eq "foo.".$config->{DATABASE_DIR}."=3");
   ok($cArray[5] eq "foo.".$config->{SUBMIT}."=4");
   ok($cArray[6] eq "foo.".$config->{STAT}."=5");
   ok($cArray[7] eq "foo.".$config->{BIN_DIR}."=6");
   ok($cArray[8] eq "foo.".$config->{MAX_NUM_RUNNING_JOBS}."=7.1");
   ok($cArray[9] eq "foo.".$config->{PANFISH_SLEEP}."=8");
   ok($cArray[10] eq "foo.".$config->{SCRATCH}."=9");
   ok($cArray[11] eq "foo.".$config->{PANFISH_VERBOSITY}."=10");
   ok($cArray[12] eq "foo.".$config->{PANFISHSUBMIT_VERBOSITY}."=11");
}

# test _getValueFromConfig with alias set on cluster passed in
{
  my $con = Panfish::Config->new();
  my $tconfig = Panfish::PanfishConfig->new();
  $con->setParameter("foo.".$tconfig->{ENGINE},"1");
  $con->setParameter("bar.".$tconfig->{ALIAS_TO},"foo");
  
  my $config = Panfish::PanfishConfig->new($con);  

  ok($config->getEngine("foo") eq "1");
  ok($config->getEngine("bar") eq "1");
  ok($config->getNotificationEmail("bar") eq "");
  ok($config->getNotificationEmail("foo") eq "");
}



1;

