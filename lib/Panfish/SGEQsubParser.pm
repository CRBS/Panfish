package Panfish::SGEQsubParser;



use strict;
use English;
use warnings;

=head1 NAME

Panfish::SGEQsubParser -- Parses output of SGE qsub to get job id

=head1 SYNOPSIS

  use Panfish::SGEQsubParser
  my $qsubParser = Panfish::SGEQsubParser->new();

  my ($jobId,$error) = $qsubParser->parse($qsubOutput);
  					   
					   
=head1 DESCRIPTION

Parses SGE qsub output to get job id
					   
=head1 METHODS


=head3 new

  Creates new Panfish::SGEQsubParser

  my $qsubParser = Panfish::SGEQsubParser->new();

=cut

sub new {
    my $class = shift;
    my $self = {
	};
    return bless ($self,$class);
}

=head3 parse

Parses output from SGE qsub call which is in the format:

Your job 1572 ("testjob.sh") has been submitted

or
 
Your job-array 1573.1-10:1 ("testjob.sh") has been submitted

In the first example above would set $jobId to 1572 and the second
example would set $jobId to 1573.1-10:1


A successful parse will result in $error below being set
to undef and $jobId will be the text before the first period.

my ($jobId,$error) = $qsub->parse("Your job 1572 ("testjob.sh") has been submitted");

=cut

sub parse {
    my $self = shift;
    my $qsubOut = shift;

    if (!defined($qsubOut) || 
        $qsubOut =~ /^ *$/){
       return(undef,"No output from qsub to parse");
    }

    # example SGE output:
    # Your job 661 ("line") has been submitted
  
    my @rows = split("\n",$qsubOut);
    my $realJobId;

    for (my $x = 0; $x < @rows; $x++){

        if ($rows[$x]=~/^Your job-array/){
            $realJobId = $rows[$x];
            $realJobId=~s/^Your job-array //;
            $realJobId=~s/ \(.*//;
            last;
        }
        elsif ($rows[$x]=~/^Your job/){
            $realJobId = $rows[$x];
            $realJobId=~s/^Your job //;
            $realJobId=~s/ \(.*//;
            last;
        }
    }

    return ($realJobId,undef);
}

1;

__END__

=head1 AUTHOR

Panfish::SGEQsubParser is written by Christopher Churas <churas@ncmir.ucsd.edu>

=cut
