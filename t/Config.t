#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More tests => 16;
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
  $con = Panfish::Config->new();
   ok(!defined($con->getAllSetValues()));

   $con->setParameter("b","bval");
   
   ok($con->getAllSetValues() eq "b=bval\n");

   $con->setParameter("a","aval");
   ok($con->getAllSetValues() eq "a=aval\nb=bval\n");

   $con->setParameter("c","cval");
   ok($con->getAllSetValues() eq "a=aval\nb=bval\nc=cval\n");

}
