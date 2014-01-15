#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More tests => 34;
use Panfish::Config;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

# test get/set parameter value
{
  my $con = Panfish::Config->new();

  ok(!defined($con->getParameterValue("unset")));
  ok($con->getParameterValue("unset","defaulttouse") eq "defaulttouse");

  $con->setParameter("unset","nowset");
  ok(!defined($con->getParameterValue("nowset")));
  ok($con->getParameterValue("unset","defaulttouse") eq "nowset");

  ok(!defined($con->getParameterValue("another")));
  $con->setParameter("another","val");
  ok($con->getParameterValue("another") eq "val");
  ok($con->getParameterValue("unset") eq "nowset");
}


# test getParameterNames
{
  my $con = Panfish::Config->new();
  ok(!defined($con->getParameterNames()));
  
  $con->setParameter("key1","nowset");
  my $arrayRef = $con->getParameterNames();
  ok(@{$arrayRef} == 1);
  ok(${$arrayRef}[0] eq "key1");

  $con->setParameter("key2","nowset2");
  $arrayRef = $con->getParameterNames();
  ok(@{$arrayRef} == 2);
  ok((${$arrayRef}[0] eq "key1" && ${$arrayRef}[1] eq "key2") ||
     (${$arrayRef}[0] eq "key2" && ${$arrayRef}[1] eq "key1"));
}


#test get all set values
{
  my $con = Panfish::Config->new();
  ok(!defined($con->getAllSetValues()));

  $con->setParameter("b","bval");
   
  ok($con->getAllSetValues() eq "b=bval\n");

  $con->setParameter("a","aval");
  ok($con->getAllSetValues() eq "a=aval\nb=bval\n");

  $con->setParameter("c","cval");
  ok($con->getAllSetValues() eq "a=aval\nb=bval\nc=cval\n");
}

# test copy
{
  # empty config copy test
  my $con = Panfish::Config->new();
  my $conCopy = $con->copy();
  ok(!defined($con->getParameterNames()));
  ok(!defined($conCopy->getParameterNames()));

  $con->setParameter("b","bval");
  $conCopy = $con->copy();
  ok($con->getAllSetValues() eq "b=bval\n");
  ok($conCopy->getAllSetValues() eq "b=bval\n");

  $conCopy->setParameter("c","cval");
  ok($con->getAllSetValues() eq "b=bval\n");
  ok($conCopy->getAllSetValues() eq "b=bval\nc=cval\n");


  $con = $conCopy->copy();
  ok($con->getAllSetValues() eq "b=bval\nc=cval\n");
  ok($conCopy->getAllSetValues() eq "b=bval\nc=cval\n");
}

# test load
{
  # test loading undef
  my $con = Panfish::Config->new();
  ok($con->load(undef) eq "Config passed in is not defined");

  # load empty self 
  ok(!defined($con->load($con))); 

  my $aCon = Panfish::Config->new();
  $aCon->setParameter("a","aval");
  ok(!defined($con->load($aCon)));
  ok($con->getAllSetValues() eq "a=aval\n");
  
  $con->setParameter("b","bval");
  ok(!defined($con->load($aCon)));
  ok($con->getAllSetValues() eq "a=aval\nb=bval\n");

  $aCon->setParameter("a","uhoh");

  ok(!defined($con->load($aCon)));
  ok($con->getAllSetValues() eq "a=uhoh\nb=bval\n");

  $cCon = Panfish::Config->new();

  ok(!defined($con->load($cCon)));
  ok($con->getAllSetValues() eq "a=uhoh\nb=bval\n");
 
}
