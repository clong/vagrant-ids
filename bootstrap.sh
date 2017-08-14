#!/usr/bin/env bash
# Author: Chris Long (@Centurion)
# Creation Date: 8/13/2017

apt-get update
export DEBIAN_FRONTEND=noninteractive
apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
## User defined packages
apt-get install -y build-essential whois jq git-core
## Suricata dependencies
apt-get install -y wget libpcre3-dev libpcre3-dbg automake autoconf libtool libpcap-dev libnet1-dev libyaml-dev zlib1g-dev libcap-ng-dev libjansson-dev pkg-config
## Bro dependencies
apt-get install -y bison cmake flex g++ gdb make libmagic-dev libpcap-dev libgeoip-dev libssl-dev python-dev swig2.0 zlib1g-dev

## Download and install Suricata
wget "https://www.openinfosecfoundation.org/download/suricata-3.2.3.tar.gz"
tar -xvf suricata-3.2.3.tar.gz
cd suricata-3.2.3
./configure --sysconfdir=/etc --localstatedir=/var
make
make install
make install-conf
mkdir /etc/suricata/rules
mkdir /var/log/suricata/certs
echo -e "\n\nYou will still have to configre your network and interfaces in /etc/suricata/suricata.yml\!\!"
# Needed to find one of the libraries required by Suricata
echo 'include /usr/local/lib/' >> /etc/ld.so.conf
ldconfig
# Copy our config over the default
cp /vagrant/resources/suricata.yaml /etc/suricata/suricata.yaml

## Download and clone the pulledpork repo
cd /opt
git clone https://github.com/shirkdog/pulledpork.git
cd pulledpork
# Copy our configs over the default
cp /vagrant/resources/disablesid.conf /opt/pulledpork/etc/
cp /vagrant/resources/pulledpork.conf /opt/pulledpork/etc/
# Needed to run CPAN in noninteractive mode
export PERL_MM_USE_DEFAULT=1
perl -MCPAN -e 'install Bundle::LWP'
perl -MCPAN -e 'install Crypt::SSLeay'
# Run pulledpork and load the rules into /etc/suricata/rules
./pulledpork.pl -c etc/pulledpork.conf -S suricata-3.0

# Determine name of default network interface
DEFAULTIF=$(ifconfig | grep ^[a-z] | grep -v lo | cut -d ' ' -f 1)
# Start suricata
# -D Daemon mode
# -c path to suricata.yaml
# -i interface
# -v verbose
suricata -D -c /etc/suricata/suricata.yaml -i $DEFAULTIF -v

# Give Suricata a few seconds to initialize and run tests
sleep 5
echo -e "Running tests...\n"
curl -A "BlackSun" example.com
sleep 3;
curl testmyids.com
sleep 3;
BLACKSUNTEST=$(grep -c 'ET USER_AGENTS Suspicious User Agent (BlackSun)' /var/log/suricata/eve.json)
if [ "$BLACKSUNTEST" -ge 1 ]; then
  echo -e "Test 1/2 passed!\n"
else
  echo -e "Test 1/2 failed! Something might be misconfigured.\n"
fi
TESTMYIDS=$(grep -c 'GPL ATTACK_RESPONSE id check returned root' /var/log/suricata/eve.json)
if [ "$TESTMYIDS" -ge 1 ]; then
  echo -e "Test 2/2 passed!\n"
else
  echo -e "Test 2/2 failed! Something might be misconfigured.\m"
fi
echo -e "Suricata has attempted to start and run tests. If tests fail, further configuration may be required.\n"

# Download GeoIP DBs for Bro
wget http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz -O /usr/share/GeoIP/GeoIPCity.dat.gz
wget http://geolite.maxmind.com/download/geoip/database/GeoLiteCityv6-beta/GeoLiteCityv6.dat.gz -O /usr/share/GeoIP/GeoIPCityv6.dat.gz
gunzip /usr/share/GeoIP/GeoIPCity.dat.gz
gunzip /usr/share/GeoIP/GeoIPCityv6.dat.gz

## Download and install Bro IDS
cd /opt
git clone --recursive git://git.bro.org/bro
cd bro
./configure --prefix=/opt/bro
make
make install
echo 'export PATH=$PATH:/opt/bro/bin' >> ~/.bashrc
source ~/.bashrc
echo -e "[bro]
type=standalone
host=localhost
interface=$DEFAULTIF" > /opt/bro/etc/node.cfg
# Enable JSON logs
echo -e 'redef LogAscii::use_json = T;' >> /opt/bro/share/bro/base/frameworks/logging/writers/ascii.bro
# Start BroIDS
/opt/bro/bin/broctl deploy

## Download and install Splunk
cd /vagrant
wget --progress=bar:force -O splunk-6.6.2-4b804538c686-linux-2.6-amd64.deb 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=6.6.2&product=splunk&filename=splunk-6.6.2-4b804538c686-linux-2.6-amd64.deb&wget=true'
dpkg -i splunk-6.6.2-4b804538c686-linux-2.6-amd64.deb
/opt/splunk/bin/splunk start --accept-license
/opt/splunk/bin/splunk add index suricata -auth 'admin:changeme'
/opt/splunk/bin/splunk add index bro -auth 'admin:changeme'
# Configure Splunk inputs
echo '[monitor:///var/log/suricata/eve.json]
index=suricata
sourcetype=suricata:json

[monitor:///opt/bro/logs/current/*.log]
index=bro
sourcetype=bro:json' >> /opt/splunk/etc/system/local/inputs.conf
# Fix broken extrations for some Bro log files
echo '[bro:json]
INDEXED_EXTRACTIONS=json
TIME_PREFIX=\"ts\"\:' > /opt/splunk/etc/system/local/props.conf
# Skip Splunk Tour and Change Password Dialog
touch /opt/splunk/etc/.ui_login
# Enable SSL login
cp /opt/splunk/etc/system/default/web.conf /opt/splunk/etc/system/local/web.conf
sed -i 's/enableSplunkWebSSL = false/enableSplunkWebSSL = true/g' /opt/splunk/etc/system/local/web.conf
# Reboot Splunk to make changes take effect
/opt/splunk/bin/splunk restart
/opt/splunk/bin/splunk enable boot-start
