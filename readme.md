# Customização de imagem JBoss 7.4 para uso do RHSSO adapter

Este repositório demonstra como customizar o JBoss para incluir na imagem da Red Hat a integração com RHSSO, também contém uma aplicação de demonstração.

A customização empregada aqui é uma feita via dockerfile.

A imagem customizada encontra-se na pasta `custom-image`. O build dela pode ser feito usando o comando:

 ```bash
 cd custom-image
 podman build . -t jboss-74-custom
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
podman tag ocpcustom $HOST/openshift/jboss-eap74-openjdk11-openshift-custom
podman login -u kubeadmin -p $(oc whoami -t) $HOST
podman push $HOST/openshift/jboss-eap74-openjdk11-openshift-custom
```

faça a criação do image stream customizado:
```bash 
cat image-stream-custom.yaml  | sed -e "s/registry.redhat.io\/jboss-eap-7\/eap74-openjdk11-openshift-rhel8/$HOST\/openshift\/jboss-eap74-openjdk11-openshift-custom/" | oc apply -f -
```



