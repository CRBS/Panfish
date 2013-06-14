package Panfish::PBSQsubParser;



use strict;
use English;
use warnings;

=head1 NAME

Panfish::PBSQsubParser -- Parses output of PBS qsub to get job id

=head1 SYNOPSIS

  use Panfish::PBSQsubParser
  my $qsubParser = Panfish::PBSQsubParser->new();

  my ($jobId,$error) = $qsubParser->parse($qsubOutput);
  					   
					   
=head1 DESCRIPTION

Parses PBS qsub output to get job id
					   
=head1 METHODS


=head3 new

  Creates new Panfish::PBSQsubParser

  my $qsubParser = Panfish::PBSQsubParser->new();

=cut

sub new {
    my $class = shift;
    my $self = {
	};
    return bless ($self,$class);
}

=head3 parse

Parses output from PBS qsub call which is in the format:

JOBID.some.other.text

A successful parse will result in $error below being set
to undef and $jobId will be the text before the first period.

my ($jobId,$error) = $qsub->parse("123.cluster.local");

=cut

sub parse {
    my $self = shift;
    my $qsubOut = shift;

    if (!defined($qsubOut) || 
        $qsubOut =~ /^ *$/){
       return(undef,"No output from qsub to parse");
    }

    # example output PBS on gordon
    # 580504.gordon-fe2.local
    my @rows = split("\n",$qsubOut);
    my $realJobId = $rows[0];
    $realJobId=~s/\..*//;

    return ($realJobId,undef);
}

1;

__END__

=head1 AUTHOR

Panfish::PBSQsubParser is written by Christopher Churas <churas@ncmir.ucsd.edu>

=cut
