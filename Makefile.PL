use 5.008008;
use ExtUtils::MakeMaker;

my $EXE_FILES = [ glob("bin/*") ];

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Panfish',
    VERSION_FROM      => 'lib/Panfish.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    EXE_FILES         => $EXE_FILES,
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Panfish.pm', # retrieve abstract from module
       AUTHOR         => 'Christopher Churas<churas@ncmir.ucsd.edu>') : ()),
);

