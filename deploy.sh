#!/bin/bash

if [ $# -ne 1 ] ; then
   echo "$0 <environment (should be prefix to properties file and .templates dir under properties/ directory>"
   exit 1
fi

DEPLOY_ENV=$1

# we are going to assume panfish Makefile.pl is in the parent directory to where the script
# is located.
PANFISH_DIR="`dirname $0`"

TIMESTAMP=`date +%m.%d.%Y.%H.%M.%S`

INSTALL_DIR_NAME="panfish.${TIMESTAMP}"

TMPINSTALLDIR="/tmp/$INSTALL_DIR_NAME"


# create tmp directory
/bin/mkdir -p $TMPINSTALLDIR

if [ $? != 0 ] ; then
  echo "Error unable to create $TMPINSTALLDIR"
  exit 1
fi

cd $PANFISH_DIR


# build panfish into a TMPINSTALLDIR
perl Makefile.PL PREFIX=$TMPINSTALLDIR

if [ $? != 0 ] ; then
   echo "Error building Panfish"
   exit 1
fi

make
if [ $? != 0 ] ; then
  echo "Error running make"
  exit 1
fi

make test
if [ $? != 0 ] ; then
  echo "Error running make test"
  exit 1
fi



make install
if [ $? != 0 ] ; then
  echo "Error running make install"
  exit 1
fi

# copy over panfish.config file into temp directory

PROPERTIES_FILE="properties/${DEPLOY_ENV}.properties"
TEMPLATE_DIR="properties/${DEPLOY_ENV}.templates"

if [ ! -s "$PROPERTIES_FILE" ] ; then
   echo "$DEPLOY_ENV is missing $PANFISH_DIR/$PROPERTIES_FILE file"
   exit 1
fi
 
if [ ! -d "$TEMPLATE_DIR" ] ; then
   echo "$DEPLOY_ENV is missing $PANFISH_DIR/$TEMPLATE_DIR directory"
   exit 1
fi


/bin/mkdir $TMPINSTALLDIR/etc

if [ $? != 0 ] ; then
  echo "Unable to make $TMPINSTALLDIR/etc"
  exit 1
fi

/bin/cp $PROPERTIES_FILE $TMPINSTALLDIR/etc/panfish.config

if [ $? != 0 ] ; then
  echo "Unable to run /bin/cp $PROPERTIES_FILE $TMPINSTALLDIR/etc/panfish.config"
  exit 1
fi

/bin/cp -a $TEMPLATE_DIR $TMPINSTALLDIR/templates

if [ $? != 0 ] ; then
  echo "Unable to run /bin/cp -a $TEMPLATE_DIR $TMPINSTALLDIR/templates"
  exit 1
fi


HOST="NOTSET"
SCP_ARG="NOTSET"


if [ "$DEPLOY_ENV" == "idoerg" ] ; then
   HOST="churas@idoerg.ucsd.edu"
   DEPLOY_BASE_DIR="/home/churas/tests/cam-dev/bin"
   SCP_ARG="${HOST}:${DEPLOY_BASE_DIR}/."
fi

if [ "$DEPLOY_ENV" == "dev" ] ; then
   HOST="tomcat@cylume.camera.calit2.net"
   DEPLOY_BASE_DIR="/camera/cam-dev/camera/release/bin"
   SCP_ARG="${HOST}:${DEPLOY_BASE_DIR}/."
fi

if [ "$DEPLOY_ENV" == "prod" ] ; then
   HOST="tomcat@cylume.camera.calit2.net"
   DEPLOY_BASE_DIR="/home/validation/camera/release/bin"
   SCP_ARG="${HOST}:${DEPLOY_BASE_DIR}/."
fi

if [ "$DEPLOY_ENV" == "cws_cylume" ] ; then
   HOST="churas@cylume.camera.calit2.net"
   DEPLOY_BASE_DIR="/home/churas/cws/bin"
   SCP_ARG="${HOST}:${DEPLOY_BASE_DIR}/."
fi

if [ "$DEPLOY_ENV" == "cws_vizwall" ] ; then
   HOST="churas@137.110.119.214"
   DEPLOY_BASE_DIR="/home/churas/panfish/cws_vizwall"
   SCP_ARG="${HOST}:${DEPLOY_BASE_DIR}/."
fi

if [ "$DEPLOY_ENV" == "megashark" ] ; then
   HOST="churas@megashark.crbs.ucsd.edu"
   DEPLOY_BASE_DIR="/sharktopus/megashark/cws/bin"
   SCP_ARG="${HOST}:${DEPLOY_BASE_DIR}/."
fi



if [ "$HOST" == "NOTSET" ] ; then
  echo "Please setup $DEPLOY_ENV in this script $0"
  exit 1
fi

# copy up new version set folder name to date timestamp
scp -r $TMPINSTALLDIR $SCP_ARG

if [ $? != 0 ] ; then
  echo "Error running scp -r $TMPINSTALLDIR $SCP_ARG"
  exit 1
fi


# change symlink by removing first then creating
ssh $HOST "/bin/rm $DEPLOY_BASE_DIR/panfish"

if [ $? != 0 ] ; then
  echo "Error running ssh $HOST \"/bin/rm $DEPLOY_BASE_DIR/panfish\""
  exit 1
fi


ssh $HOST "/bin/ln -s $DEPLOY_BASE_DIR/$INSTALL_DIR_NAME  $DEPLOY_BASE_DIR/panfish"

if [ $? != 0 ] ; then
  echo "Error running ssh $HOST \"/bin/ln -s $DEPLOY_BASE_DIR/$INSTALL_DIR_NAME  $DEPLOY_BASE_DIR/panfish\""
  exit 1
fi


# exit
