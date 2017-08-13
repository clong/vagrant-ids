# Vagrant-IDS

# Purpose
This Vagrant file will spin up an Ubuntu 16.04 box (Bento) and install and configure the following software:
* Suricata (3.2.8 - Latest stable build at time of writing)
* PulledPork
* Bro (Latest)
* Splunk (6.6.2 - Latest at time of writing)

## Setup
1. Install a provider (Virtualbox/VMWare/etc)
2. Install [Vagrant](https://www.vagrantup.com/)
3. `$ git clone https://github.com/Centurion89/vagrant-ids.git`
4. `$ cd vagrant-ids`
5. `$ vagrant up --provider=[vmware_fusion/virtualbox/etc]`

## Suricata
The suricata.yaml file that will be installed includes a few small changes, primarily:
* JSON logging (eve.json) is enabled and configured fairly verbosely
* The config assumes HOME_NET = 192.168.0.0/16
* The only rule file being imported is pulledpork.rules

Suricata is configured to startup using the sole "ens32" interface. Rules are stored in `/etc/suricata/rules`.

After installation, Suricata will perform two curl commands to ensure that the detection engine and logging are functioning properly. However, please note that the vagrant build will continue even if the tests fail.

## PulledPork
[PulledPork](https://github.com/shirkdog/pulledpork) is used to configure rule management and updates in Suricata. It is installed in /opt/pulledpork and is configured to pull down EmergingThreats rules. You can manually run PulledPork via `/opt/pulledpork/pulledpork.pl -c etc/pulledpork.conf -S suricata-3.0`. Also consider adding that command to cron if you would like updates to run on a schedule automatically

## Bro
Bro is cloned and installed into `/opt/bro`. Similar to Suricata, it assumes all RFC1918 is part of private networks and uses "ens32" as the interface it monitors. JSON logging is enabled and it is configured to run in standalone mode.

## Splunk
Splunk will be installed with two indexes:
* suricata
* bro

Access Splunk at https://vagrant:8000. The default credentials are `admin:changeme` and can be changed via CLI or web interface.

By default, Splunk is configured to ingest `/var/log/suricata/eve.json` and all ".log" files in `/opt/bro/logs/current/`. To modify what logs are collected, edit `/opt/splunk/etc/system/local/inputs.conf`

## Contributing
If you encounter any issues or would like to request any features, please feel free to submit a PR or create an issue.

## References
* [How to Install and Configure Bro on Ubuntu Linux](https://komunity.komand.com/learn/article/network-security/how-to-install-and-configure-bro-on-ubuntu-linux/)
* [How To Install Bro-IDS 2.2 on Ubuntu 12.04](https://www.digitalocean.com/community/tutorials/how-to-install-bro-ids-2-2-on-ubuntu-12-04)
*  [How to install Suricata intrusion detection system on Linux](http://xmodulo.com/install-suricata-intrusion-detection-system-linux.html)
* [Install Perl modul with assume yes for given options non-interactively](https://stackoverflow.com/questions/18458194/install-perl-modul-with-assume-yes-for-given-options-non-interactively)
