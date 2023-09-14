#!/usr/bin/env bash
source /usr/local/s2i/install-common.sh

injected_dir=$1
echo "Running on injected_dir=${injected_dir}"

install_modules ${injected_dir}/modules
/opt/eap/bin/jboss-cli.sh --file="/opt/eap/bin/adapter-elytron-install-offline.cli" -Dserver.config="standalone-openshift.xml"

echo "End CLI configuration"