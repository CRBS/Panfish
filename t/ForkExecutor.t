#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Test::More tests => 23;
require Panfish::ForkExecutor;

SKIP: {
   skip "Skipping Linux/Mac Executor tests on windows",23 if $^O=~/Win/;
   my $pid = $$;
   
   my $exec = Panfish::ForkExecutor->new();
   
#test exec does the right thing on bad command
   ok($exec->executeCommand("time -p we9jfls 2>&1") != 0);
   ok($exec->getExitCode() != 0);
   ok($exec->getCommand() eq "time -p we9jfls 2>&1");
   
   ok($exec->getOutput()=~/time: cannot run/ || $exec->getOutput()=~/command not found/ || $exec->getOutput()=~/No such file or/);
   
#test valid command
   ok($exec->executeCommand("time -p true 2>&1") == 0);
   ok($exec->getExitCode() == 0);
   ok($exec->getCommand() eq "time -p true 2>&1");
   
   ok ($exec->getOutput()=~/real *[0-9]*.[0-9]*\nuser *[0-9]*.[0-9]*\nsys *[0-9]*.[0-9]*\n/);
   
#test command that takes too long
   ok($exec->executeCommand("time -p sleep 50 2>&1",2) != 0);
   ok($exec->getExitCode() != 0);
   ok($exec->getCommand() eq "time -p sleep 50 2>&1");
   ok ($exec->getOutput() eq "Runtime Exceeded 2 seconds process killed by parent");
   
   
   ok (checkForProcess($pid,"TestForkBSExecutor") == 0);
   ok (checkForProcess($pid,"sleep") == 0);
   ok (checkForProcess($pid,"time") == 0);
   
#test command that takes too long but has output
   ok($exec->executeCommand("sleep 2;echo \"hi\";sleep 2 2>&1",3) != 0);
   ok($exec->getExitCode() != 0);
   ok($exec->getCommand() eq "sleep 2;echo \"hi\";sleep 2 2>&1");
   
   ok($exec->getOutput() eq "Runtime Exceeded 3 seconds process killed by parent");
   
#test command that takes too long but has output after 2 seconds
#and if we enable time reset this command should now succeed
   ok($exec->executeCommand("sleep 2;echo \"hi\";sleep 2 2>&1",3,1) == 0);
   ok($exec->getExitCode() == 0);
   ok($exec->getCommand() eq "sleep 2;echo \"hi\";sleep 2 2>&1");
   ok($exec->getOutput() eq "hi\n");
   
#
# Function to check for a specific process
#
   sub checkForProcess {
       my $processid = shift;
       my $process_name = shift;
       
       my $x;
       my @pidsplit;
       my $psout = `ps x -o pid,ppid,command`;

       my @lines = split('\n',$psout);
       
       for ($x = 1; $x < @lines; $x++){
	   @pidsplit = split(' ',$lines[$x]);
	if ($pidsplit[1] eq $processid){
	    if ($pidsplit[2]=~/$process_name/){
		return 1;
	    }
	    checkForProcess($pidsplit[0],$process_name);
	}
       }
       return 0;
   }
}
