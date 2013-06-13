#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib $Bin;

use Test::More tests => 16;
use Mock::FileUtil;
use Mock::Logger;
use Mock::FileReaderWriter;
use Panfish::PanfishConfigFactory;
use Panfish::Config;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


#test with no panfish.config file found anywhere
{
    my $blog = Mock::Logger->new();
    
    my $fUtil = Mock::FileUtil->new();

    $fUtil->addRunFileTestResult("-e",$ENV{"HOME"}."/.panfish.config",0);
    $fUtil->addRunFileTestResult("-e","$Bin/../etc/panfish.config",0);
    $fUtil->addRunFileTestResult("-e","$Bin/panfish.config",0);
    $fUtil->addRunFileTestResult("-e","/etc/panfish.config",0);    

    my $reader = Mock::FileReaderWriter->new();
    my $pcf = Panfish::PanfishConfigFactory->new($reader,$fUtil,$blog);

    my $config = $pcf->getPanfishConfig();     

    ok(!defined($config));

    my @rows = $blog->getLogs();
   
    if ($ENV{"PANFISH_CONFIG"}){
       fail("Test requires PANFISH_CONFIG environment variable to be unset");
    }
    my $cnt = 0;
    ok(@rows == 5);    
    ok($rows[$cnt++]=~/DEBUG Attempting to parse config from: .*.panfish.config/);
    ok($rows[$cnt++]=~/DEBUG Attempting to parse config from: .*\.\.\/etc\/panfish.config/);
    ok($rows[$cnt++]=~/DEBUG Attempting to parse config from: .*\/panfish.config/);
    ok($rows[$cnt++]=~/DEBUG Attempting to parse config from: \/etc\/panfish.config/);
    ok($rows[$cnt++]=~/ERROR Unable to load config from any of these locations: .*/);
    
}

#test with a valid panfish.config file and then rewrite panfish.config with alternate values and check that
# too
{
    my $blog = Mock::Logger->new();

    my $fUtil = Mock::FileUtil->new();

    $fUtil->addRunFileTestResult("-e",$ENV{"HOME"}."/.panfish.config",1);
    $fUtil->addRunFileTestResult("-e",$ENV{"HOME"}."/.panfish.config",1);

    my $reader = Mock::FileReaderWriter->new();
    $reader->addOpenFileResult(">".$ENV{"HOME"}."/.panfish.config",undef);
    $reader->addReadResult("this.cluster=foo\n");
    $reader->addReadResult("foo.scratch=/tmp\n");
    my $pcf = Panfish::PanfishConfigFactory->new($reader,$fUtil,$blog);

    my $config = $pcf->getPanfishConfig();

    ok(defined($config));
    ok($config->getThisCluster() eq "foo");
    ok($config->getScratchDir() eq "/tmp");

    $reader->addOpenFileResult(">".$ENV{"HOME"}."/.panfish.config",undef);
    $reader->addReadResult("this.cluster=bahh\n");
    $reader->addReadResult("bahh.scratch=/yo\n");

    $config = $pcf->getPanfishConfig($config);
    ok($config->getThisCluster() eq "bahh");
    ok($config->getScratchDir() eq "/yo");
    ok($config->getScratchDir("foo") eq "");


    my @rows = $blog->getLogs();
    ok(@rows == 2);
    ok($rows[0]=~/DEBUG.*Attempting to parse config from:.*\.panfish.config/);
    ok($rows[1]=~/DEBUG.*Attempting to parse config from:.*\.panfish.config/);

}


