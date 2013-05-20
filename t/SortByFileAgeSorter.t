#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib $Bin;

use Test::More tests => 14;
use Panfish::SortByFileAgeSorter;
use Mock::FileUtil;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


# sort 1 file
{
   my $futil = Mock::FileUtil->new();
   my $sorter = Panfish::SortByFileAgeSorter->new($futil);

   my @files;
   $files[0]="file1";

   $futil->addRunFileTestResult("-M",$files[0],100);

   my @sortedFiles = $sorter->sort(\@files);

   ok(@sortedFiles == 1);
   ok($sortedFiles[0] eq $files[0]);
}

#
# Sort 2 files where first is older then the second
#
{
   my $futil = Mock::FileUtil->new();
   my $sorter = Panfish::SortByFileAgeSorter->new($futil);

   my @files;
   $files[0]="file1";
   $files[1]="file2";

   $futil->addRunFileTestResult("-M",$files[0],100);
   $futil->addRunFileTestResult("-M",$files[1],50);

   my @sortedFiles = $sorter->sort(\@files);

   ok(@sortedFiles == 2);
   ok($sortedFiles[0] eq $files[0]);
   ok($sortedFiles[1] eq $files[1]);
}


#
# Sort 2 files where first is younder then the second
#
{
   my $futil = Mock::FileUtil->new();
   my $sorter = Panfish::SortByFileAgeSorter->new($futil);

   my @files;
   $files[0]="file1";
   $files[1]="file2";

   $futil->addRunFileTestResult("-M",$files[0],50);
   $futil->addRunFileTestResult("-M",$files[1],100);

   my @sortedFiles = $sorter->sort(\@files);

   ok(@sortedFiles == 2);
   ok($sortedFiles[0] eq $files[1]);
   ok($sortedFiles[1] eq $files[0]);
}

#
# Sort 5 files
#
{
   my $futil = Mock::FileUtil->new();
   my $sorter = Panfish::SortByFileAgeSorter->new($futil);

   my @files;
   $files[0]="file1";
   $files[1]="file2";
   $files[2]="file3";
   $files[3]="file4";
   $files[4]="file5";
 


   $futil->addRunFileTestResult("-M",$files[0],50); 
   $futil->addRunFileTestResult("-M",$files[1],101);
   $futil->addRunFileTestResult("-M",$files[2],110);
   $futil->addRunFileTestResult("-M",$files[3],300);
   $futil->addRunFileTestResult("-M",$files[4],100);

   $futil->addRunFileTestResult("-M",$files[0],50);
   $futil->addRunFileTestResult("-M",$files[1],101);
   $futil->addRunFileTestResult("-M",$files[2],110);
   $futil->addRunFileTestResult("-M",$files[3],300);
   $futil->addRunFileTestResult("-M",$files[4],100);

   $futil->addRunFileTestResult("-M",$files[0],50);
   $futil->addRunFileTestResult("-M",$files[1],101);
   $futil->addRunFileTestResult("-M",$files[2],110);
   $futil->addRunFileTestResult("-M",$files[3],300);
   $futil->addRunFileTestResult("-M",$files[4],100);


   $futil->addRunFileTestResult("-M",$files[0],50);
   $futil->addRunFileTestResult("-M",$files[1],101);
   $futil->addRunFileTestResult("-M",$files[2],110);
   $futil->addRunFileTestResult("-M",$files[3],300);
   $futil->addRunFileTestResult("-M",$files[4],100);


   my @sortedFiles = $sorter->sort(\@files);

   ok(@sortedFiles == 5);
   ok($sortedFiles[0] eq $files[3]);
   ok($sortedFiles[1] eq $files[2]);
   ok($sortedFiles[2] eq $files[1]);
   ok($sortedFiles[3] eq $files[4]);
   ok($sortedFiles[4] eq $files[0]);
}





1;
