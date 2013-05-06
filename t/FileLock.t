#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib $Bin;

use Test::More tests => 15;
use Panfish::FileLock;
use Mock::FileReaderWriter;
use Mock::Executor;
use Mock::Logger;
use Mock::FileUtil;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

#
# Test create lock when no lock file is set
#
{
   my $logger = Mock::Logger->new(1);
   my $mockexec = Mock::Executor->new();
   my $futil = Mock::FileUtil->new();
   my $readerwriter = Mock::FileReaderWriter->new();
   my $lock = Panfish::FileLock->new($logger,$futil,$mockexec,$readerwriter);

   ok($lock->create(undef,123) eq "Lockfile is not set");
   my @logs = $logger->getLogs();
   ok(@logs == 1);
   ok($logs[0] =~/ERROR Lockfile is not set/);
}


#
# Test create lock when pid is not set
#
{
   my $logger = Mock::Logger->new(1);
   my $mockexec = Mock::Executor->new();
   my $futil = Mock::FileUtil->new();
   my $readerwriter = Mock::FileReaderWriter->new();
   my $lock = Panfish::FileLock->new($logger,$futil,$mockexec,$readerwriter);

   ok($lock->create("/tmp/locky",undef) eq "Pid is not set");
   my @logs = $logger->getLogs();
   ok(@logs == 1);
   ok($logs[0] =~/ERROR Pid is not set/);
}

#
# Test create where lock file does not exist but openfile fails to work
# to create lock
#
{
   my $logger = Mock::Logger->new(1);
   my $mockexec = Mock::Executor->new();
   my $futil = Mock::FileUtil->new();
   my $readerwriter = Mock::FileReaderWriter->new();
   my $lock = Panfish::FileLock->new($logger,$futil,$mockexec,$readerwriter);

   $futil->addRunFileTestResult("-f","/tmp/locky",undef);
   $readerwriter->addOpenFileResult(">/tmp/locky","someerror");
   ok($lock->create("/tmp/locky","123") eq "Unable to open /tmp/locky for writing : someerror");
   my @logs = $logger->getLogs();
   ok(@logs == 1);
   ok($logs[0] =~/ERROR Unable to open \/tmp\/locky for writing : someerror/);
}

#
# Test create where lock file does not exist and code is able to write out a new
# lock file
#
{
   my $logger = Mock::Logger->new(1);
   my $mockexec = Mock::Executor->new();
   my $futil = Mock::FileUtil->new();
   my $readerwriter = Mock::FileReaderWriter->new();
   my $lock = Panfish::FileLock->new($logger,$futil,$mockexec,$readerwriter);

   $futil->addRunFileTestResult("-f","/tmp/locky",undef);
   $readerwriter->addOpenFileResult(">/tmp/locky",undef);
   
   ok(!defined($lock->create("/tmp/locky","123")));
   my @logs = $logger->getLogs();
   ok(@logs == 1);
   ok(!defined($logs[0]));
}

# Test create where lock file does exist and has a pid
{
   my $logger = Mock::Logger->new(1);
   my $mockexec = Mock::Executor->new();
   my $futil = Mock::FileUtil->new();
   my $readerwriter = Mock::FileReaderWriter->new();
   my $lock = Panfish::FileLock->new($logger,$futil,$mockexec,$readerwriter);

   $futil->addRunFileTestResult("-f","/tmp/locky",1);
   $readerwriter->addOpenFileResult("/tmp/locky",undef);
   $readerwriter->addReadResult("444");
   ok($lock->create("/tmp/locky","123") eq "Lock file /tmp/locky with pid 444 found.  Unable to create lock");
   my @logs = $logger->getLogs();
   ok(@logs == 1);
   ok($logs[0] =~ /Lock file \/tmp\/locky with pid 444 found.  Unable to create lock/);
}

1;
