#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More tests => 13;
use Panfish::FileUtil;
use Panfish::Logger;
use Panfish::FileReaderWriterImpl;
use Panfish::PanfishConfigFactory;
use Panfish::Config;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


#test with no panfish.config file found
{
    my $logoutput;
    my $foo;
    open $foo,'>',\$logoutput;

    #delete panfish.config
    my $fUtil = Panfish::FileUtil->new();
    ok($fUtil->deleteFile("$Bin/panfish.config") == 1);

    my $blog = Panfish::Logger->new();
    $blog->setLevelBasedOnVerbosity(2);
    $blog->setOutput($foo);
    my $reader = Panfish::FileReaderWriterImpl->new($blog);
    my $pcf = Panfish::PanfishConfigFactory->new($reader,$blog);

    my $config = $pcf->getPanfishConfig();     

    ok(!defined($config));

    my @rows = split("\n",$logoutput);
    ok(@rows == 1);

    ok($rows[0]=~/Unable to load config from.* or .*/);
    
    close($foo);
}

#test with a valid panfish.config file and then rewrite panfish.config with alternate values and check that
# too
{
    my $logoutput;
    my $foo;
    open $foo,'>',\$logoutput;

    my $blog = Panfish::Logger->new();
    $blog->setLevelBasedOnVerbosity(0);
    $blog->setOutput($foo);

    my $writer = Panfish::FileReaderWriterImpl->new($blog);
    $writer->openFile(">$Bin/panfish.config");
    $writer->write("this.cluster=foo\nfoo.scratch=/tmp\n");
    $writer->close();
    $blog->setLevelBasedOnVerbosity(2);
    my $reader = Panfish::FileReaderWriterImpl->new($blog);

    my $pcf = Panfish::PanfishConfigFactory->new($reader,$blog);

    my $config = $pcf->getPanfishConfig();

    ok(defined($config));
    ok($config->getThisCluster() eq "foo");
    ok($config->getScratchDir() eq "/tmp");

    $blog->setLevelBasedOnVerbosity(0);
    $writer->openFile(">$Bin/panfish.config");
    $writer->write("this.cluster=bahh\nbahh.scratch=/yo\n");
    $writer->close();

    $blog->setLevelBasedOnVerbosity(2);
    $config = $pcf->getPanfishConfig($config);
    ok($config->getThisCluster() eq "bahh");
    ok($config->getScratchDir() eq "/yo");
    ok(!defined($config->getScratchDir("foo")));


    my @rows = split("\n",$logoutput);
    ok(@rows == 2);
    ok($rows[0]=~/DEBUG.*Attempting to parse config from:.*\/panfish.config/);
    ok($rows[1]=~/DEBUG.*Attempting to parse config from:.*\/panfish.config/);

    close($foo);
}


