#!/usr/bin/env bash
source /usr/local/s2i/install-common.sh

# descomente para debug do script 
# set -x

install_modules /custom/modules
/opt/eap/bin/jboss-cli.sh --file="/opt/eap/bin/adapter-elytron-install-offline.cli" -Dserver.config="standalone-openshift.xml"

rm -rf /opt/eap/standalone/data
rm -rf /opt/eap/standalone/configuration/standalone_xml_history
rm -rf /opt/eap/standalone/tmp/vfs
rm -rf /opt/eap/standalone/log

echo "End CLI configuration"