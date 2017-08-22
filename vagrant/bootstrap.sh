#!/usr/bin/env bash

echo "Installing base packages"
yum install -y cmake git epel-release tcsh unzip wget gzip

cd /opt
wget http://dl.dropbox.com/u/47200624/respin/ge2011.11.tar.gz
tar -zxf ge2011.11.tar.gz
chown -R root.root /opt/ge2011.11
cd ge2011.11
cp /vagrant/qmaster.template.conf .
./inst_sge -x -noremote -auto qmaster.template.conf

. /opt/ge2011.11/default/common/settings.sh
qstat




echo ""
echo "Installation complete..."
echo ""
echo ""
