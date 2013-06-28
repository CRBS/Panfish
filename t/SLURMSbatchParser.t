#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib $Bin;

use Test::More tests => 10;
use Panfish::SLURMSbatchParser;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


my $parser = Panfish::SLURMSbatchParser->new();
my ($jobid,$error);


# test parse where undef is passed in
($jobid,$error) = $parser->parse(undef);
ok(!defined($jobid));
ok($error eq "No output from sbatch to parse");

# test parse with empty string is passed in
($jobid,$error) = $parser->parse("");
ok(!defined($jobid));
ok($error eq "No output from sbatch to parse");

($jobid,$error) = $parser->parse(" ");
ok(!defined($jobid));
ok($error eq "No output from sbatch to parse");



# test parse with just id no period
($jobid,$error) = $parser->parse("Submitted batch job 1572");
ok($jobid == 1572);
ok(!defined($error));

# test parse with array job which will return the whole thing
($jobid,$error) = $parser->parse("blah\n\blah\nSubmitted batch job 1573");
ok($jobid eq "1573");
ok(!defined($error));


