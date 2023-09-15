# Customização de imagem JBoss 7.4 para uso do RHSSO adapter

Este repositório demonstra como customizar o JBoss para incluir na imagem da Red Hat a integração com RHSSO, também contém uma aplicação de demonstração.

A customização empregada aqui é uma feita via dockerfile.

A imagem customizada encontra-se na pasta `custom-image`. São fornecidos duas formas de customizar, uma é feita no build da imagem, já configurando o JBoss com as opções desejadas, e outra é feita usando o (postconfigure)[https://access.redhat.com/documentation/en-us/red_hat_jboss_enterprise_application_platform/7.4/html-single/getting_started_with_jboss_eap_for_openshift_container_platform/index#custom_scripts].

O build da imagem pré configurada pode ser feito usando o comando abaixo:
 ```bash
 cd custom-image
 podman build -f config-in-image.Dockerfile . -t jboss-74-custom
 ```

O build da imagem usando customização usando o método de postconfigure, pode ser feito usando o comando abaixo:
```bash
 cd custom-image
 podman build -f config-in-postconfigure.Dockerfile . -t jboss-74-custom
 ```


Obtivemos o patch mais recente do adaptador RHSSO para o JBoss EAP 7.x disponível no site [Red Hat Single Sign-On 7.6.5 Client Adapter for JBoss EAP 7](https://access.redhat.com/jbossnetwork/restricted/softwareDetail.html?softwareId=105638&product=core.service.rhsso&version=7.6&downloadType=patches)




Preparação

Realização da exposição do registry do openshift para upload da imagem customizada, conforme orientação da [documentação](https://docs.openshift.com/container-platform/4.12/registry/securing-exposing-registry.html)

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

Execução de um build usando o image stream customizado:

```bash
oc new-project demo
oc delete bc app-demo
oc new-build jboss-eap74-openjdk11-openshift-custom:latest~https://github.com/mycloudlab/jboss-eap74-openshift-with-rhsso-adapter#main \
--context-dir app-demo \
--name=app-demo
```


oc new-app --name=app-demo app-demo 

oc expose app-demo