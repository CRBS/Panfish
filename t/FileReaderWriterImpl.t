#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Camera-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More tests => 8;
use Panfish::FileReaderWriterImpl;

#########################



# Test opening a valid file with 3 lines in it.
{
    # remove existing test directory and make a new one
    # using external command cause its easier to do
    my $testdir = $Bin."/testFileReaderWriterImpl";
    `perl -MExtUtils::Command -e rm_rf $testdir`;
    `perl -MExtUtils::Command -e mkpath $testdir`;



    my $writer = Panfish::FileReaderWriterImpl->new();
    
    my $first = "$testdir/first.txt";

    ok(!defined($writer->openFile(">$first")));

    $writer->write("hello\nhow\nare\n");
    $writer->close();
 
    my $fr = Panfish::FileReaderWriterImpl->new();
    
    ok(defined($fr));

    ok(!defined($fr->openFile($first)));
    ok($fr->read() eq "hello\n");
    ok($fr->read() eq "how\n");
    ok($fr->read() eq "are\n");
    ok(!defined($fr->read()));
    ok(!defined($fr->close()));
}

