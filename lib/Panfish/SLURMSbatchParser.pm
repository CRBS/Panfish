package Panfish::SLURMSbatchParser;



use strict;
use English;
use warnings;

=head1 NAME

Panfish::SLURMSbatchParser -- Parses output of SLURM sbatch to get job id

=head1 SYNOPSIS

  use Panfish::SLURMSbatchParser
  my $sbatchParser = Panfish::SLURMSbatchParser->new();

  my ($jobId,$error) = $sbatchParser->parse($sbatchOutput);
  					   
					   
=head1 DESCRIPTION

Parses output of SLURM sbatch to get job id
					   
=head1 METHODS


=head3 new

  Creates new Panfish::SLURMSbatchParser

  my $sbatchParser = Panfish::SLURMSbatchParser->new();

=cut

sub new {
    my $class = shift;
    my $self = {
	};
    return bless ($self,$class);
}

=head3 parse

Parses output from SLURM batch call which is in the format:


$ sbatch somejob.sh
Submitted batch job 995463

In the example above would set $jobId to 995463.  

The code will look for the first occurrence of "^Submitted batch job "
and grab the value at the end of the line.

A successful parse will result in $error below being set
to undef and $jobId will be the text before the first period.

my ($jobId,$error) = $qsub->parse("blah\nblah\nSubmitted batch job 995463");

=cut

sub parse {
    my $self = shift;
    my $sbatchOut = shift;

    if (!defined($sbatchOut) || 
        $sbatchOut =~ /^ *$/){
       return(undef,"No output from sbatch to parse");
    }

    # example sbatch output:
    # Submitted batch job 995463
  
    my @rows = split("\n",$sbatchOut);
    my $realJobId;

    for (my $x = 0; $x < @rows; $x++){

        if ($rows[$x]=~/^Submitted batch job /){
            $realJobId = $rows[$x];
            $realJobId=~s/^Submitted batch job //;
            $realJobId=~s/^.*job //;
            last;
        }
    }

    return ($realJobId,undef);
}

1;

__END__

=head1 AUTHOR

Panfish::SLURMsbatchParser is written by Christopher Churas <churas@ncmir.ucsd.edu>

=cut
