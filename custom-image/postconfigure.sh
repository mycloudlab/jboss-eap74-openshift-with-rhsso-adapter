#!/usr/bin/env bash
set -x
source /usr/local/s2i/install-common.sh

install_modules /custom/modules
/opt/eap/bin/jboss-cli.sh --file="/opt/eap/bin/adapter-elytron-install-offline.cli" -Dserver.config="standalone-openshift.xml"

echo "End CLI configuration"