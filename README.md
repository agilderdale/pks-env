# pks-env

## support-scripts/setup-pks-client.sh

This script is for setting up PKS Client VM from the scratch.
Only basic Ubuntu image is required - I personally use Ubuntu Desktop version to have browser:
https://www.ubuntu.com/download/desktop
#Tested on Ubuntu 18.04 LTS
Run as root:
```
sudo bash -c "$(wget -O - https://raw.githubusercontent.com/agilderdale/pks-env/master/support-scripts/setup-pks-client.sh)"
```
## support-scripts/setup-pks-pipelines.sh

This script is for setting up concourse pipeline to run NSX-T and PKS install and config.
Tested on Ubuntu 18.04 LTS
Run as root:

Make sure that /etc/resolv.conf file on PKS Client VM is pointing to DNS that can resolve gihub.com, etc.
You can run this script by calling following command from the command line:
```
sudo bash -c "$(wget -O - https://raw.githubusercontent.com/agilderdale/pks-env/master/support-scripts/setup-pks-pipelines.sh)"
```
