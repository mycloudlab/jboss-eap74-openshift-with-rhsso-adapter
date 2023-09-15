FROM registry.redhat.io/jboss-eap-7/eap74-openjdk11-openshift-rhel8:7.4.12-5

COPY rh-sso-7.6.5-eap-adapter/modules /custom/modules
COPY rh-sso-7.6.5-eap-adapter/bin/adapter-elytron-install-offline.cli /opt/eap/bin

COPY --chmod=0755 postconfigure.sh /opt/eap/extensions/postconfigure.sh
