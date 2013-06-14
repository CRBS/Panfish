#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib $Bin;

use Test::More tests => 12;
use Panfish::PBSQsubParser;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


my $parser = Panfish::PBSQsubParser->new();
my ($jobid,$error);


# test parse where undef is passed in
($jobid,$error) = $parser->parse(undef);
ok(!defined($jobid));
ok($error eq "No output from qsub to parse");

# test parse with empty string is passed in
($jobid,$error) = $parser->parse("");
ok(!defined($jobid));
ok($error eq "No output from qsub to parse");

($jobid,$error) = $parser->parse(" ");
ok(!defined($jobid));
ok($error eq "No output from qsub to parse");



# test parse with just id no period
($jobid,$error) = $parser->parse("12345");
ok($jobid = 12345);
ok(!defined($error));

# test parse with multiple periods
($jobid,$error) = $parser->parse("123444.gordon-f3.local");
ok($jobid = 123444);
ok(!defined($error));


# test parse with period as first character
($jobid,$error) = $parser->parse(".123444.gordon-f3.local");
ok($jobid eq "");
ok(!defined($error));



