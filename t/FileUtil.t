#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Camera-SGEProjectAssigner.t'

#########################

use File::stat;
use Fcntl ':mode';

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib $Bin;

use Test::More tests => 126;
use Panfish::FileReaderWriterImpl;
use Panfish::FileUtil;
use Panfish::Logger;
use Mock::Logger;
#########################

$|=1;

# Test copy, move, chmod, and unlink a file
{
    my $logoutput;
    my $foo;
    open $foo,'>',\$logoutput;

    my $blog = Panfish::Logger->new();
    $blog->setLevelBasedOnVerbosity(2);
    $blog->setOutput($foo);

    my $fUtil = Panfish::FileUtil->new($blog);

    # remove existing test directory and make a new one
    # using external command cause its easier to do
    my $testdir = $Bin."/testFileUtil";
    $fUtil->recursiveRemoveDir($testdir);
    $fUtil->makeDir($testdir);

    my $writer = Panfish::FileReaderWriterImpl->new();
    
    my $first = "$testdir/first.txt";

    ok(!defined($writer->openFile(">$first")));
    $writer->write("somedata\n");
    $writer->close();
    ok(-f $first);
    my $firstSize = -s $first;
    

    #lets try a copy
    my $firstcopy = $first.".2";
    ok($fUtil->copyFile($first,$firstcopy) == 1);
    
    ok(-f $firstcopy);
    ok(-s $first == -s $firstcopy);
    
    
    #now a move 
    my $second = $first.".moved";
    ok($fUtil->moveFile($first,$second) == 1);

    ok(! -f $first);

    ok(-f $second);

    ok(-s $second == $firstSize);

    #now a move over existing file?
    my $existFile = "$testdir/existing.txt";
    ok(!defined($writer->openFile(">$existFile")));
    $writer->write("zzzzzzzzzzzzzz\n");
    $writer->close();
    ok(-s $second != -s $existFile);
    ok($fUtil->moveFile($second,$existFile) == 1);
    ok(! -f $second);

    ok(-s $existFile == $firstSize);

    $sb = stat($existFile);
    my $humanReadablePerm = sprintf("%04o",$sb->mode & 07777);
    ok($humanReadablePerm ne "0755");

    #lets try a chmod
    ok($fUtil->makePathUserGroupExecutableAndReadable($existFile) == 1); 
    
    $sb = stat($existFile);
    $humanReadablePerm = sprintf("%04o",$sb->mode & 07777);
    ok($humanReadablePerm eq "0755");
    
    #now a delete
    ok($fUtil->deleteFile($existFile) == 1);
    ok(! -f $existFile); 

    ok(!defined($logoutput));
    close($foo);
}

# getDirname tests
{
   my $logoutput;
    my $foo;
    open $foo,'>',\$logoutput;
    my $blog = Panfish::Logger->new();
    $blog->setLevelBasedOnVerbosity(2);
    $blog->setOutput($foo);

    my $fUtil = Panfish::FileUtil->new($blog);

    ok($fUtil->getDirname("/foo/blah") eq "/foo");

    ok($fUtil->getDirname("//foo//blah") eq "//foo");

    ok($fUtil->getDirname("/") eq "/");

    ok(!defined($fUtil->getDirname()));

    ok($fUtil->getDirname("") eq ".");
    ok($fUtil->getDirname(".") eq ".");
    ok($fUtil->getDirname("..") eq ".");
    close($foo);
}


# getFilesInDirectory undef path
{
   my $logoutput;
    my $foo;
    open $foo,'>',\$logoutput;
    my $blog = Panfish::Logger->new();
    $blog->setLevelBasedOnVerbosity(2);
    $blog->setOutput($foo);

   my $fUtil = Panfish::FileUtil->new($blog);
   ok(!defined($fUtil->getFilesInDirectory(undef)));
   my @rows = split("\n",$logoutput);
   ok(@rows == 1);
   ok($rows[0]=~/ERROR.*Directory path to search not set/);

   close($foo);
}

# getNumberFilesInDirectory undef path
{
   my $logoutput;
    my $foo;
    open $foo,'>',\$logoutput;
    my $blog = Panfish::Logger->new();
    $blog->setLevelBasedOnVerbosity(2);
    $blog->setOutput($foo);

   my $fUtil = Panfish::FileUtil->new($blog);
   ok($fUtil->getNumberFilesInDirectory(undef)==0);
   my @rows = split("\n",$logoutput);
   ok(@rows == 1);
   ok($rows[0]=~/ERROR.*Directory path to search not set/);

   close($foo);
}



# getFilesInDirectory non directory path
{
   my $logoutput;
    my $foo;
    open $foo,'>',\$logoutput;
    my $blog = Panfish::Logger->new();
    $blog->setLevelBasedOnVerbosity(2);
    $blog->setOutput($foo);

   my $fUtil = Panfish::FileUtil->new($blog);
   ok(!defined($fUtil->getFilesInDirectory("$Bin/asdssdfjklsdflkjsdfjkl")));
   my @rows = split("\n",$logoutput);
   ok(@rows == 1);
   ok($rows[0]=~/ERROR.*Unable to open /);

   close($foo);
}

# getNumberFilesInDirectory non directory path
{
   my $logoutput;
    my $foo;
    open $foo,'>',\$logoutput;
    my $blog = Panfish::Logger->new();
    $blog->setLevelBasedOnVerbosity(2);
    $blog->setOutput($foo);

   my $fUtil = Panfish::FileUtil->new($blog);
   ok($fUtil->getNumberFilesInDirectory("$Bin/asdssdfjklsdflkjsdfjkl")==0);
   my @rows = split("\n",$logoutput);
   ok(@rows == 1);
   ok($rows[0]=~/ERROR.*Unable to open /);

   close($foo);
}


# getFilesInDirectory in dir with nothing in it
{
   my $logoutput;
    my $foo;
    open $foo,'>',\$logoutput;
    my $blog = Panfish::Logger->new();
    $blog->setLevelBasedOnVerbosity(2);
    $blog->setOutput($foo);

   my $fUtil = Panfish::FileUtil->new($blog);
   # remove existing test directory and make a new one
   # using external command cause its easier to do
    my $testdir = $Bin."/testFileUtil";
    $fUtil->recursiveRemoveDir($testdir);
    ok($fUtil->makeDir($testdir) == 1);


   #completely empty directory
   my @files = $fUtil->getFilesInDirectory($testdir);
   ok($fUtil->getNumberFilesInDirectory($testdir) == 0);
   ok(@files == 0);

  
   #directory full of other directories
   ok($fUtil->makeDir("$testdir/one") == 1);
   @files = $fUtil->getFilesInDirectory($testdir);
   ok(@files == 0);
   ok($fUtil->getNumberFilesInDirectory($testdir) == 0);
   ok($fUtil->makeDir("$testdir/two") == 1);
   @files = $fUtil->getFilesInDirectory($testdir);
   ok(@files == 0);

   ok($fUtil->getNumberFilesInDirectory($testdir) == 0);
   ok(!defined($logoutput));

   close($foo);
}

# getFilesInDirectory with different counts of files, directories and symlinks
# test getNumberFilesInDirectory at the same time
{
    my $logoutput;
    my $foo;
    open $foo,'>',\$logoutput;
    my $blog = Panfish::Logger->new();
    $blog->setLevelBasedOnVerbosity(2);
    $blog->setOutput($foo);

   my $fUtil = Panfish::FileUtil->new($blog);
   # remove existing test directory and make a new one
   # using external command cause its easier to do
    my $testdir = $Bin."/testFileUtil";
    $fUtil->recursiveRemoveDir($testdir);
    ok($fUtil->makeDir($testdir) == 1);

    my $writer = Panfish::FileReaderWriterImpl->new();

    my $first = "$testdir/first.txt";

    ok(!defined($writer->openFile(">$first")));
    $writer->write("somedata\n");
    $writer->close();


   #one file
   my @files = $fUtil->getFilesInDirectory($testdir);
   ok($fUtil->getNumberFilesInDirectory($testdir) == 1);

   ok(@files == 1);
   ok($files[0] eq $first);


   #directory full of other directories
   ok($fUtil->makeDir("$testdir/one") == 1);
   @files = $fUtil->getFilesInDirectory($testdir);
   ok($fUtil->getNumberFilesInDirectory($testdir) == 1);
   ok(@files == 1);
   ok($fUtil->makeDir("$testdir/two") == 1);
   @files = $fUtil->getFilesInDirectory($testdir);
   ok($fUtil->getNumberFilesInDirectory($testdir) == 1);
   ok(@files == 1);

   my %fHash = ();
   
   for (my $x = 0; $x < 10; $x++){
      ok(!defined($writer->openFile(">$first.$x")));
      $fHash{"$first.$x"}="written";
      $writer->write("somedata\n");
      $writer->close();
   }
   #add in first file from above to hash
   $fHash{$first} = "written";
   
   @files = $fUtil->getFilesInDirectory($testdir);
   # need to verify we have all 11 files
   for (my $x = 0; $x < @files; $x++){
       ok($fHash{$files[$x]} eq "written");
       $fHash{$files[$x]}="found";
   }
   for my $key ( keys %fHash ) {
        ok($fHash{$key} eq "found");
   }
   ok($fUtil->getNumberFilesInDirectory($testdir) == 11);
   ok(@files == 11);
   ok(!defined($logoutput));

   close($foo);


}

# test getDirectorySize with depth of 2 and 2 files
{
   my $logger = Mock::Logger->new();
   my $fUtil = Panfish::FileUtil->new($logger);

   # remove existing test directory and make a new one
   # using external command cause its easier to do
   my $testdir = $Bin."/testFileUtil";
   $fUtil->recursiveRemoveDir($testdir);
   ok($fUtil->makeDir($testdir) == 1);

   ok($fUtil->makeDir($testdir."/one") == 1);
   ok($fUtil->makeDir($testdir."/one/two") == 1);   

    my $writer = Panfish::FileReaderWriterImpl->new();

    my $first = "$testdir/first.txt";

    ok(!defined($writer->openFile(">$first")));
    $writer->write("somedata\n");
    $writer->close();

    $first = "$testdir/one/second.txt";

    ok(!defined($writer->openFile(">$first")));
    $writer->write("somedata\n");
    $writer->close();

    my ($numFiles,$numDirs,$numSymLinks,$sizeInBytes,$error) = $fUtil->getDirectorySize($testdir);
    ok($numFiles == 2);
    ok($numDirs == 3);
    ok($numSymLinks == 0);
    ok($sizeInBytes == 18);
    ok(!defined($error));

    ok(!defined($logger->getLogs()));
}

# test getDirectorySize with a simple link to external directory that is fine
{
   my $logger = Mock::Logger->new();
   my $fUtil = Panfish::FileUtil->new($logger);

   my $testdir = $Bin."/testFileUtil";
   $fUtil->recursiveRemoveDir($testdir);
   ok($fUtil->makeDir($testdir) == 1);

   ok($fUtil->makeDir($testdir."/one") == 1);
   ok($fUtil->makeDir($testdir."/two") == 1);
   

    my $writer = Panfish::FileReaderWriterImpl->new();

    my $first = "$testdir/two/first.txt";

    ok(!defined($writer->openFile(">$first")));
    $writer->write("somedata\n");
    $writer->close();


    $first = "$testdir/one/second.txt";

    ok(!defined($writer->openFile(">$first")));
    $writer->write("somedata\n");
    $writer->close();

    ok(eval{ symlink($testdir."/two",$testdir."/one/twolink")});

    my ($numFiles,$numDirs,$numSymLinks,$sizeInBytes,$error) = $fUtil->getDirectorySize($testdir."/one");
    ok($numFiles == 2);
    ok($numDirs == 2);
    ok($numSymLinks == 1);
    ok($sizeInBytes == 18);
    ok(!defined($error));

    ok(!defined($logger->getLogs()));
}


# test getDirectorySize with a circular link
{
   my $logger = Mock::Logger->new();
   my $fUtil = Panfish::FileUtil->new($logger);

   my $testdir = $Bin."/testFileUtil";
   $fUtil->recursiveRemoveDir($testdir);
   ok($fUtil->makeDir($testdir) == 1);

   ok($fUtil->makeDir($testdir."/one") == 1);
   ok(eval{ symlink($testdir."/one",$testdir."/one/circular")});

    my $writer = Panfish::FileReaderWriterImpl->new();

    my $first = "$testdir/first.txt";

    ok(!defined($writer->openFile(">$first")));
    $writer->write("somedata\n");
    $writer->close();

    $first = "$testdir/one/second.txt";

    ok(!defined($writer->openFile(">$first")));
    $writer->write("somedata\n");
    $writer->close();

    my ($numFiles,$numDirs,$numSymLinks,$sizeInBytes,$error) = $fUtil->getDirectorySize($testdir);
    ok($error eq "Reached max directory depth of 20");

    my @logs = $logger->getLogs();
    ok(@logs == 1);
    ok($logs[0] =~/ERROR Reached max directory depth of 20/);
}

