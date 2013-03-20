use 5.008008;
use ExtUtils::MakeMaker;


my $EXE_FILES = [ glob("bin/*") ];

my $PROPERTIES_FILE = "properties/local.properties";

#check for -properties flag which denotes a property file to use for deployment
if (defined($ARGV[0]) && $ARGV[0]=~/-properties.file/ &&
    defined($ARGV[1])){
    $PROPERTIES_FILE = $ARGV[1];
}


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

sub MY::postamble {
  my $build = buildtarget();

  #read contents of properties file looking for path to
  #properties file to copy over
  my $server_host = "";
  my $server_priv_key = "";
  my $panfish_bin = "";
  my $panfish_old = "";
  my $template_dir = "";
  open(DATA,$PROPERTIES_FILE) || die $!;
  while(<DATA>){
    my $line = $_;
    chomp($line);
    if ($line=~/^#/ || $line!~m/^(.*)=(.*)$/){
        next;
    }

    my $equalIndex = index($line,"=");
    my $key = substr($line,0,$equalIndex);
    my $value = substr($line,$equalIndex+1,length($line));
    if (lc($key) eq "server.host"){
        $server_host = $value;
    }
    if (lc($key) eq "server.priv.key"){
        $server_priv_key = $value;
    }
    if (lc($key) eq "panfish.bin"){
    $panfish_bin = $value;
    }
    if (lc($key) eq "panfish.old.bin"){
        $panfish_old = $value;
    }
    if (lc($key) eq "template.dir"){
        $template_dir = $value;
    }
  } 
  my $olddate = time();
  
  $build =~s/CAMNAME/panfish/g;
  $build =~s/PANFISH_BIN/$panfish_bin/g;
  $build =~s/PANFISH_OLD/$panfish_old/g;
  $build =~s/SERVER_PRIV_KEY/$server_priv_key/g;
  $build =~s/SERVER_HOST/$server_host/g;
  $build =~s/PROPERTIES/$PROPERTIES_FILE/g;
  $build =~s/DTIMESTAMP/$olddate/g;
  $build =~s/TEMPLATE_DIR/$template_dir/g;
  return $build;
} 

sub buildtarget {
return <<MAKE_FRAG;
camera: all
	\$(ECHO) "Building CAMNAME"
	\$(RM_RF) CAMNAME
	\$(MKPATH) CAMNAME
	\$(MKPATH) CAMNAME/bin
	\$(MKPATH) CAMNAME/etc
	\$(MKPATH) CAMNAME/templates
	\$(MKPATH) CAMNAME/share
	\$(MKPATH) CAMNAME/share/man/man3
	\$(MKPATH) CAMNAME/share/man/man1
	\$(CP) PROPERTIES CAMNAME/etc/panfish.config
	\$(CP) -pPR TEMPLATE_DIR/* CAMNAME/templates/.
	\$(CP) -pPR \$(INST_SCRIPT)/* CAMNAME/bin/.
	\$(CP) -pPR \$(INST_LIB) CAMNAME
	\$(CP) -pPR \$(INST_MAN1DIR)/*.\$(MAN1EXT) CAMNAME/share/man/man1
	\$(CP) -pPR \$(INST_MAN3DIR)/*.\$(MAN3EXT) CAMNAME/share/man/man3
	\$(CHMOD) -R go-w CAMNAME
	\$(CHMOD) -R a+rx CAMNAME/bin
cameradist: camera
	\$(ECHO) "Building CAMNAME camera distributable"
	\$(TAR) -c CAMNAME > CAMNAME-\$(VERSION).tar
cameradeploy: camera
	ssh SERVER_PRIV_KEY SERVER_HOST '/bin/mkdir PANFISH_OLD/panfish.DTIMESTAMP' || exit 2
	ssh SERVER_PRIV_KEY SERVER_HOST '/bin/mv PANFISH_BIN/* PANFISH_OLD/panfish.DTIMESTAMP/.' || exit 2
	scp SERVER_PRIV_KEY -r CAMNAME/* SERVER_HOST:PANFISH_BIN/. 2>&1 || exit 2
	\$(ECHO) "CAMNAME successfully deployed.  Have a nice day"
cameraclean: clean
	\$(RM_RF) CAMNAME
	\$(RM_F) CAMNAME-\$(VERSION).tar*

MAKE_FRAG
}

