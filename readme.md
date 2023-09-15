# Customização de imagem JBoss 7.4 para uso do RHSSO adapter

Este repositório demonstra como customizar o JBoss para incluir na imagem da Red Hat a integração com RHSSO, também contém uma aplicação de demonstração.


## Pré-requisitos

- OpenShift 
- podman

## Customizações para imagem s2i do JBoss EAP 7.4

A Red Hat disponibiliza uma imagem s2i para execução do JBoss EAP sob o OpenShift, `registry.redhat.io/jboss-eap-7/eap74-openjdk11-openshift-rhel8:7.4.12-5` as vezes pode ser necessário fazer ajustes para que as aplicações executem corretamente sob o JBoss, portanto são fornecidos e documentados, diversas formas de construir a imagem usando o s2i e fazendo essas customizações.

### Customização via projeto


A customização via projeto é feita colocando os scripts de configuração diretamente no repositório da aplicação, conforme apontado na (documentação)[https://access.redhat.com/documentation/en-us/red_hat_jboss_enterprise_application_platform/7.4/html/getting_started_with_jboss_eap_for_openshift_container_platform/configuring_eap_openshift_image#s2i_modules_drivers_deployments]

#### Funcionamento

Basicamente, deve ser criado uma pasta dentro do diretório do projeto que deverá conter um script de install.sh, juntamente com os módulos e configurações de drivers.

A documentação informa que o script install.sh roda sem limitações, servido de gancho para executar operações de customizações necessárias a imagem. A documentação dá um exemplo do script install.sh, que mostro abaixo:
```bash
#!/bin/bash

injected_dir=$1
source /usr/local/s2i/install-common.sh
install_deployments ${injected_dir}/injected-deployments.war
install_modules ${injected_dir}/modules
configure_drivers ${injected_dir}/drivers.env
```

Ao colocar esses arquivos no repositório git você deve configurar a variável de ambiente `CUSTOM_INSTALL_DIRECTORIES` ao fazer o build e especificar o diretório dentro do projeto que tem as customizações. Digamos que a pasta se chama custom, então o build deveria ser feito assim:

```bash
oc new-build jboss-eap74-openjdk11-openshift-custom:latest~https://github.com/mycloudlab/jboss-eap74-openshift-with-rhsso-adapter#main \
--context-dir app-demo \
--env=CUSTOM_INSTALL_DIRECTORIES="custom" \
--name=app-demo
```

Essa customização não é alvo das demonstrações de configuração.

#### Prós & contras

Benefícios dessa abordagem:
- A configuração fica disponível para o desenvolvedor.
- Simples para aplicar configurações customizadas.
- Altamente customizável por usar o install.sh script.

Contras dessa abordagem:
- Configuração aplicada em tempo de build do source-to-image da imagem, o que pode fazer o processo de build demorar um pouco mais, devido as configurações necessárias a serem aplicadas.
- O desenvolvedor tem total liberdade na customização - em ambientes mais controlados isso pode ser um problema ou limitante.
- Configuração fica exposta no repositório GIT.

### Customização direto na imagem  

A customização direto na imagem consiste em deixar a imagem utilizada no source-to-image com as configurações necessárias ao projeto. Isso pode ser feito com um dockerfile customizado a partir da imagem fornecida pela Red Hat. 

Neste exemplo a customização envolve a configuração do adaptador do RHSSO no JBoss usando o projeto do elytron, para isso obtivemos o patch mais recente do adaptador RHSSO para o JBoss EAP 7.x disponível no site [Red Hat Single Sign-On 7.6.5 Client Adapter for JBoss EAP 7](https://access.redhat.com/jbossnetwork/restricted/softwareDetail.html?softwareId=105638&product=core.service.rhsso&version=7.6&downloadType=patches)

#### Funcionamento

A customização empregada aqui é uma feita via dockerfile.

A imagem customizada encontra-se em `custom-image/config-in-image.Dockerfile`. 

```dockerfile
FROM registry.redhat.io/jboss-eap-7/eap74-openjdk11-openshift-rhel8:7.4.12-5

COPY rh-sso-7.6.5-eap-adapter/modules /custom/modules
COPY rh-sso-7.6.5-eap-adapter/bin/adapter-elytron-install-offline.cli /opt/eap/bin

COPY --chmod=0755 install.sh /custom

RUN /custom/install.sh
```

A customização aqui é feita usando o cli do JBoss usando um script de install.sh usado para configurar o JBoss em tempo de build da imagem, a customização aqui empregada executa um script cli fornecido pelo adapter do RHSSO da Red Hat, para instalação no JBoss.

Essas alterações ocorre na fase antes do processo do source-to-image portanto deve ser feito uma limpeza das pastas log, tmp, data e histórico de alterações do standalone-openshift.xml.

Abaixo segue o script de install.sh com as devidas limpezas necessárias para tornar a imagem usável em runtime com as configurações aplicadas:

```bash
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
```

O build da imagem pré configurada pode ser feito usando o comando abaixo:
 ```bash
 cd custom-image
 podman build -f config-in-image.Dockerfile . -t jboss-74-custom
 ```

Neste ponto temos uma imagem JBoss EAP 7.4 customizado, para utilizar ela no OpenShift a imagem deve ser disponibilizada em um registry e aplicada no processo de build por um ImageStream customizado. O imageStream encontra-se em `custom-image/image-stream-custom.yaml`.

Para simplificar a demonstração do funcionamento das customizações usamos neste exemplo o registry interno do OpenShift, portanto realizamos a exposição do registry do openshift para upload da imagem customizada, conforme orientação da [documentação](https://docs.openshift.com/container-platform/4.12/registry/securing-exposing-registry.html)

```bash
oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge
```

Para obter o endereço do registry usamos o comando: 
```bash
HOST=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')
```

Faça o push da imagem para o registry, no exemplo estou sando o registry do próprio OpenShift:
```bash
podman login -u kubeadmin -p $(oc whoami -t) $HOST
podman tag jboss-74-custom $HOST/openshift/jboss-eap74-openjdk11-openshift-custom
podman push $HOST/openshift/jboss-eap74-openjdk11-openshift-custom
```

faça a criação do image stream customizado:
```bash 
cat image-stream-custom.yaml  | sed -e "s/registry.redhat.io\/jboss-eap-7\/eap74-openjdk11-openshift-rhel8/$HOST\/openshift\/jboss-eap74-openjdk11-openshift-custom/" | oc apply -f -
```

Execução de um build usando o image stream customizado, o build é de uma aplicação de demonstração fornecida aqui na pasta `app-demo`:

```bash
oc new-project demo
oc delete bc app-demo
oc new-build jboss-eap74-openjdk11-openshift-custom:latest~https://github.com/mycloudlab/jboss-eap74-openshift-with-rhsso-adapter#main \
--context-dir app-demo \
--name=app-demo
```

Com isso o build será feito e a imagem conterá a customização feita.

Colocando a aplicação demo de exemplo em execução, após o build da imagem da app: 

```bash
oc new-app --name=app-demo app-demo 
oc expose service app-demo --path='/simple-webapp-oidc'
```

#### Prós & contras

Benefícios dessa abordagem:
- Customização feita direto na imagem sem acesso aos desenvolvedores.
- Configuração aplicada em tempo de pré-build do source-to-image acelerando o processo de build.

Contras dessa abordagem:
- Controle manual do ciclo de vida e atualizações para imagens fornecidas pela Red Hat.
- Solução mais complexa e não completamente documentada, pois envolve alterações direto na imagem fornecida da Red Hat, o que pode fazer o SLA trabalhar em modo best-effort, caso seja detectado no suporte que o problema relatado esteja relacionado as customizações empregadas.

### Customização via script postconfigure.sh

Outra forma de fazer a customização é usando a abordagem de configuração em tempo de runtime, fornecendo na imagem um script de postconfigure.sh, esta abordagem é fornecida na (documentação)[https://access.redhat.com/documentation/en-us/red_hat_jboss_enterprise_application_platform/7.4/html-single/getting_started_with_jboss_eap_for_openshift_container_platform/index#custom_scripts].

#### Funcionamento

A configuração aqui também e feita via utilização de uma imagem customizada, na imagem fornecemos os arquivos de configuração necessários e colocamos o script postconfigure.sh na pasta `/opt/eap/extensions`, o script postconfigure.sh é um gancho que é executado antes de inicializar a aplicação, fornecendo um método conveniente para ajustes do JBoss antes da execução da aplicação.

Neste exemplo a customização envolve a configuração do adaptador do RHSSO no JBoss usando o projeto do elytron, para isso obtivemos o patch mais recente do adaptador RHSSO para o JBoss EAP 7.x disponível no site [Red Hat Single Sign-On 7.6.5 Client Adapter for JBoss EAP 7](https://access.redhat.com/jbossnetwork/restricted/softwareDetail.html?softwareId=105638&product=core.service.rhsso&version=7.6&downloadType=patches)

A imagem customizada encontra-se em `custom-image/config-in-image.Dockerfile`. 

```dockerfile
FROM registry.redhat.io/jboss-eap-7/eap74-openjdk11-openshift-rhel8:7.4.12-5

COPY rh-sso-7.6.5-eap-adapter/modules /custom/modules
COPY rh-sso-7.6.5-eap-adapter/bin/adapter-elytron-install-offline.cli /opt/eap/bin

COPY --chmod=0755 postconfigure.sh /opt/eap/extensions/postconfigure.sh
```

O script postconfigure.sh encontra-se em `custom-image/postconfigure.sh` e é exemplificado abaixo:
```bash
#!/usr/bin/env bash
source /usr/local/s2i/install-common.sh

# descomente para debug do script 
# set -x

install_modules /custom/modules
/opt/eap/bin/jboss-cli.sh --file="/opt/eap/bin/adapter-elytron-install-offline.cli" -Dserver.config="standalone-openshift.xml"

echo "End CLI configuration"
``` 

O build da imagem usando customização usando o método de postconfigure, pode ser feito usando o comando abaixo:
```bash
 cd custom-image
 podman build -f config-in-postconfigure.Dockerfile . -t jboss-74-custom
 ```

Neste ponto temos uma imagem JBoss EAP 7.4 customizado, para utilizar ela no OpenShift a imagem deve ser disponibilizada em um registry e aplicada no processo de build por um ImageStream customizado. O imageStream encontra-se em `custom-image/image-stream-custom.yaml`.

Para simplificar a demonstração do funcionamento das customizações usamos neste exemplo o registry interno do OpenShift, portanto realizamos a exposição do registry do openshift para upload da imagem customizada, conforme orientação da [documentação](https://docs.openshift.com/container-platform/4.12/registry/securing-exposing-registry.html)

```bash
oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge
```

Para obter o endereço do registry usamos o comando: 
```bash
HOST=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')
```

Faça o push da imagem para o registry, no exemplo estou sando o registry do próprio OpenShift:
```bash
podman login -u kubeadmin -p $(oc whoami -t) $HOST
podman tag jboss-74-custom $HOST/openshift/jboss-eap74-openjdk11-openshift-custom
podman push $HOST/openshift/jboss-eap74-openjdk11-openshift-custom
```

faça a criação do image stream customizado:
```bash 
cat image-stream-custom.yaml  | sed -e "s/registry.redhat.io\/jboss-eap-7\/eap74-openjdk11-openshift-rhel8/$HOST\/openshift\/jboss-eap74-openjdk11-openshift-custom/" | oc apply -f -
```

Execução de um build usando o image stream customizado, o build é de uma aplicação de demonstração fornecida aqui na pasta `app-demo`:

```bash
oc new-project demo
oc delete bc app-demo
oc new-build jboss-eap74-openjdk11-openshift-custom:latest~https://github.com/mycloudlab/jboss-eap74-openshift-with-rhsso-adapter#main \
--context-dir app-demo \
--name=app-demo
```

Com isso o build será feito e a imagem conterá a customização feita.

Colocando a aplicação demo de exemplo em execução, após o build da imagem da app: 

```bash
oc new-app --name=app-demo app-demo 
oc expose service app-demo --path='/simple-webapp-oidc'
```

#### Prós & contras

Benefícios dessa abordagem:
- Customização feita direto na imagem sem acesso aos desenvolvedores.
- Abordagem amplamente documentada.

Contras dessa abordagem:
- Start da aplicação mais demorado pois são aplicadas em tempo de runtime, antes da aplicação iniciar.
- Controle manual do ciclo de vida e atualizações para imagens fornecidas pela Red Hat.
- Solução mais complexa, pois envolve alterações direto na imagem fornecida da Red Hat, o que pode fazer o SLA trabalhar em modo best-effort, caso seja detectado no suporte que o problema relatado esteja relacionado as customizações empregadas.
