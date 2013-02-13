#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Panfish-SGEProjectAssigner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More tests => 41;
use Panfish::Logger;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

#test default constructor and verify all log levels are output
{
    my $logoutput;
    my $foo;
    open $foo,'>',\$logoutput;

    my $blog = Panfish::Logger->new();
    $blog->setOutput($foo);
    $blog->debug("aaa");
    $blog->info("bbb");
    $blog->warn("ccc");
    $blog->error("ddd");
    $blog->fatal("eee");
    
    my @rows = split("\n",$logoutput);
    ok($rows[0]=~/DEBUG.*aaa/);
    ok($rows[1]=~/INFO.*bbb/);
    ok($rows[2]=~/WARN.*ccc/);
    ok($rows[3]=~/ERROR.*ddd/);
    ok($rows[4]=~/FATAL.*eee/);
    close($foo);
}

#test setting level to an invalid value which will result 
#in all levels being output
{
    my $logoutput;
    my $foo;
    open $foo,'>',\$logoutput;
    
    my $blog = Panfish::Logger->new();
    $blog->setOutput($foo);
    $blog->setLevel("blah");
    $blog->debug("aaa");
    $blog->info("bbb");
    $blog->warn("ccc");
    $blog->error("ddd");
    $blog->fatal("eee");

    my @rows = split("\n",$logoutput);
    ok(@rows == 5);
    ok($rows[0]=~/DEBUG.*aaa/);
    ok($rows[1]=~/INFO.*bbb/);
    ok($rows[2]=~/WARN.*ccc/);
    ok($rows[3]=~/ERROR.*ddd/);
    ok($rows[4]=~/FATAL.*eee/);
    close($foo);
}


#test setting level to undef which will result in all
#levels being output
{
    my $logoutput;
    my $foo;
    open $foo,'>',\$logoutput;

    my $blog = Panfish::Logger->new();
    $blog->setOutput($foo);
    $blog->setLevel(undef);
    $blog->debug("aaa");
    $blog->info("bbb");
    $blog->warn("ccc");
    $blog->error("ddd");
    $blog->fatal("eee");

    my @rows = split("\n",$logoutput);
    ok(@rows == 5);
    ok($rows[0]=~/DEBUG.*aaa/);
    ok($rows[1]=~/INFO.*bbb/);
    ok($rows[2]=~/WARN.*ccc/);
    ok($rows[3]=~/ERROR.*ddd/);
    ok($rows[4]=~/FATAL.*eee/);
    close($foo);
}

#test default constructor and setLevel to DEBUG and verify all log levels are output
{
    my $logoutput;
    my $foo;
    open $foo,'>',\$logoutput;

    my $blog = Panfish::Logger->new();
    $blog->setOutput($foo);
    $blog->setLevel("DEBUG");
    $blog->debug("aaa");
    $blog->info("bbb");
    $blog->warn("ccc");
    $blog->error("ddd");
    $blog->fatal("eee");
    
    my @rows = split("\n",$logoutput);
    ok(@rows == 5);
    ok($rows[0]=~/DEBUG.*aaa/);
    ok($rows[1]=~/INFO.*bbb/);
    ok($rows[2]=~/WARN.*ccc/);
    ok($rows[3]=~/ERROR.*ddd/);
    ok($rows[4]=~/FATAL.*eee/);
    close($foo);
}

#test default constructor and setLevel to INFO
# and verify INFO and above are output
{
    my $logoutput;
    my $foo;
    open $foo,'>',\$logoutput;

    my $blog = Panfish::Logger->new();
    $blog->setOutput($foo);
    $blog->setLevel("INFO");
    $blog->debug("aaa");
    $blog->info("bbb");
    $blog->warn("ccc");
    $blog->error("ddd");
    $blog->fatal("eee");
    
    my @rows = split("\n",$logoutput);
    ok(@rows == 4);
    ok($rows[0]=~/INFO.*bbb/);
    ok($rows[1]=~/WARN.*ccc/);
    ok($rows[2]=~/ERROR.*ddd/);
    ok($rows[3]=~/FATAL.*eee/);
    close($foo);
}


#test default constructor and setLevel to WARN
# and verify WARN and above are output
{
    my $logoutput;
    my $foo;
    open $foo,'>',\$logoutput;

    my $blog = Panfish::Logger->new();
    $blog->setOutput($foo);
    $blog->setLevel("WARN");
    $blog->debug("aaa");
    $blog->info("bbb");
    $blog->warn("ccc");
    $blog->error("ddd");
    $blog->fatal("eee");

    my @rows = split("\n",$logoutput);
    ok(@rows == 3);
    ok($rows[0]=~/WARN.*ccc/);
    ok($rows[1]=~/ERROR.*ddd/);
    ok($rows[2]=~/FATAL.*eee/);
    close($foo);
}

#test default constructor and setLevel to ERROR
# and verify ERROR and above are output
{
    my $logoutput;
    my $foo;
    open $foo,'>',\$logoutput;

    my $blog = Panfish::Logger->new();
    $blog->setOutput($foo);
    $blog->setLevel("ERROR");
    $blog->debug("aaa");
    $blog->info("bbb");
    $blog->warn("ccc");
    $blog->error("ddd");
    $blog->fatal("eee");

    my @rows = split("\n",$logoutput);
    ok(@rows == 2);
    ok($rows[0]=~/ERROR.*ddd/);
    ok($rows[1]=~/FATAL.*eee/);
    close($foo);
}

#test default constructor and setLevel to FATAL
# and verify FATAL and above are output
{
    my $logoutput;
    my $foo;
    open $foo,'>',\$logoutput;

    my $blog = Panfish::Logger->new();
    $blog->setOutput($foo);
    $blog->setLevel("FATAL");
    $blog->debug("aaa");
    $blog->info("bbb");
    $blog->warn("ccc");
    $blog->error("ddd");
    $blog->fatal("eee");

    my @rows = split("\n",$logoutput);
    ok(@rows == 1);
    ok($rows[0]=~/FATAL.*eee/);
    close($foo);
}


#try calling log messagse without setting anything
#to make sure it does not die
{
    my $logger = Panfish::Logger->new();
    ok(defined($logger));
    $logger->error("test");
    $logger->fatal("real fatal");
    $logger->info("foo");
    ok(1 == 1);
}

#try calling log messagse where email is set to undef
#to make sure it does not die
{
    my $logger = Panfish::Logger->new();
    $logger->setNotificationEmail(undef);
    $logger->error("test");
    $logger->fatal("real fatal");
    $logger->info("foo");
    ok(1 == 1);
}

#try calling log messagse where email is set to a space
#to make sure it does not die
{
    my $logger = Panfish::Logger->new();
    $logger->setNotificationEmail(" ,asdfasdf");
    $logger->error("test");
    $logger->fatal("real fatal");
    $logger->info("foo");
    ok(1 == 1);
}





