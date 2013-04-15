#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Camera-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib $Bin;

use Test::More tests => 8;
use Panfish::FileReaderWriterImpl;
use Panfish::ConfigFromFileFactory;
use Panfish::Config;
use Panfish::FileUtil;
use Mock::Logger;
#########################


# Test opening an invalid non existant file
{

   my $blog = Mock::Logger->new(1);

 
  my $fr = Panfish::FileReaderWriterImpl->new($blog);
  my $cFac = Panfish::ConfigFromFileFactory->new($fr,$blog);

  my $config = $cFac->getConfig($Bin."/asdfljasdljasdfljksadlj;f");

  ok(!defined($config));
}

# Test opening an empty file
{
   my $testdir = $Bin."/testConfigFromFileFactory";

   my $blog = Mock::Logger->new(1);

   my $fUtil = Panfish::FileUtil->new($blog);
   $fUtil->recursiveRemoveDir($testdir);
   $fUtil->makeDir($testdir);

   my $fr = Panfish::FileReaderWriterImpl->new($blog);
   $fr->openFile(">$testdir/empty");
   $fr->close();
   my $cFac = Panfish::ConfigFromFileFactory->new($fr,$blog);

   my $config = $cFac->getConfig("$testdir/empty");
   ok(defined($config));  
}


# Test opening a valid file with 3 lines in it.
{
    # remove existing test directory and make a new one
    # using external command cause its easier to do
    my $testdir = $Bin."/testConfigFromFileFactory";
    `perl -MExtUtils::Command -e rm_rf $testdir`;
    `perl -MExtUtils::Command -e mkpath $testdir`;

    my $writer = Panfish::FileReaderWriterImpl->new();
    
    my $first = "$testdir/first.txt";

    ok(!defined($writer->openFile(">$first")));

    $writer->write("key1=val1\nkey2=val2\nkey3 = val3\nkey4 = val4=val5");
    $writer->close();
 
    my $fr = Panfish::FileReaderWriterImpl->new();

    my $cFac = Panfish::ConfigFromFileFactory->new($fr);

    my $config = $cFac->getConfig($first);

    ok(defined($config));
    ok($config->getParameterValue("key1") eq "val1");
    ok($config->getParameterValue("key2") eq "val2");
    ok($config->getParameterValue("key3") eq "val3");
    ok($config->getParameterValue("key4") eq "val4=val5");
}

