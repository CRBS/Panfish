#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More tests => 22;
use Panfish::JobState;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

# test basic get methods
{
    ok(Panfish::JobState->UNKNOWN() eq "unknown");
    ok(Panfish::JobState->SUBMITTED() eq "submitted");
    ok(Panfish::JobState->QUEUED() eq "queued");
    ok(Panfish::JobState->BATCHED() eq "batched");
    ok(Panfish::JobState->BATCHEDANDCHUMMED() eq "batchedandchummed");
    ok(Panfish::JobState->RUNNING() eq "running");
    ok(Panfish::JobState->DONE() eq "done");
    ok(Panfish::JobState->FAILED() eq "failed");
}


# test getAllStates
{
   my @states = Panfish::JobState->getAllStates();
 
   ok(@states == 7);
   ok($states[0] eq Panfish::JobState->SUBMITTED());
   ok($states[1] eq Panfish::JobState->QUEUED());
   ok($states[2] eq Panfish::JobState->BATCHED());
   ok($states[3] eq Panfish::JobState->BATCHEDANDCHUMMED());
   ok($states[4] eq Panfish::JobState->RUNNING());
   ok($states[5] eq Panfish::JobState->DONE());
   ok($states[6] eq Panfish::JobState->FAILED());
   
}

# test getAllNotCompleteStates
{
   my @states = Panfish::JobState->getAllNotCompleteStates();

   ok(@states == 5);
   ok($states[0] eq Panfish::JobState->SUBMITTED());
   ok($states[1] eq Panfish::JobState->QUEUED());
   ok($states[2] eq Panfish::JobState->BATCHED());
   ok($states[3] eq Panfish::JobState->BATCHEDANDCHUMMED());
   ok($states[4] eq Panfish::JobState->RUNNING());
}

