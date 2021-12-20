#!/bin/bash
echo "------------------------------------AMBASSADOR------------------------------------"

####--------CHECKING HELM EXISTENCE------------
output=$(helm version | grep "version.BuildInfo" )
if [[ -n $output ]]
then
    echo " "
else
    echo "-----------Installing HELM---------"
    wget https://get.helm.sh/helm-v3.6.0-linux-amd64.tar.gz
    tar xvf helm-v3.6.0-linux-amd64.tar.gz
    sudo mv linux-amd64/helm /usr/local/bin
    ./get_helm.sh
    rm helm-v3.6.0-linux-amd64.tar.gz
fi

###----CHECKING CERT-MANAGER NAMESPACE EXISTENCE--- 
namespace=$(kubectl get ns | grep "ambassador" )

if [[ -n $namespace  ]]
then
    echo "namespace ambassador already exists"
else
    kubectl create ns ambassador
fi
kubectl apply -f https://www.getambassador.io/yaml/aes-crds.yaml 





#--------CHECKING HELM REPO EXISTENCE-------

repo=$(helm repo list | grep datawire)
if [[ -n $repo  ]]
then
    echo "repo  already exists"
else
    helm repo add datawire https://www.getambassador.io 
fi
#-----HELM INSTALLING AND UPGRADING PART----
cd ambassador

helm repo update
helm upgrade --install ambassador-aes1 datawire/ambassador -n ambassador \
-f values.yaml \
--atomic \
--timeout 10m \
--debug

kubectl apply -f global.yaml -f tls.yaml



#!/bin/bash
echo "------------------------------------CERT-MANAGER------------------------------------"

####--------CHECKING HELM EXISTENCE------------
output=$(helm version | grep "version.BuildInfo" )
if [[ -n $output ]]
then
    echo " "
else 
    echo "-----installing HELM"
    wget https://get.helm.sh/helm-v3.6.0-linux-amd64.tar.gz
    tar xvf helm-v3.6.0-linux-amd64.tar.gz
    sudo mv linux-amd64/helm /usr/local/bin
    rm helm-v3.6.0-linux-amd64.tar.gz
fi

###----CHECKING CERT-MANAGER NAMESPACE EXISTENCE--- 
namespace=$(kubectl get ns | grep "cert-manager" )
echo $namespace
if [[ -n $namespace  ]]
then
    echo "namespace cert-manager already exists"
else
    kubectl create ns cert-manager
fi


cd ../cert-manager ##DIRECTORY IN WHICH THERE ARE CREDENTIALS.JSON AND VALUES.YAML
#------------CREATING SECRET FROM CREDENTIALS.JSON-----
secret=$(kubectl get secret | grep "prod-cert-manager" )
if [[-n $secret ]]
then
    echo "secret prod-cert-manager alreay exists"
else
    kubectl create secret generic prod-cert-manager --from-file=credentials.json -n cert-manager
fi

kubectl apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.13/deploy/manifests/00-crds.yaml

#--------CHECKING HELM REPO EXISTENCE-------
repo=$(helm repo list | grep jetstack)
if [[ -n $repo  ]]
then
    echo "repo already exists"
else
    helm repo add jetstack https://charts.jetstack.io 
fi
#-----HELM INSTALLING AND UPGRADING PART----

helm repo update 
helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager \
--version v0.13.1 \
--atomic \
--wait 

#-----CHECKING LINKERD EXISTENCE-------
link=$(linkerd version | grep "Client version")
if [[ -n $link]]
then
    echo " "
else
    echo "---------INSTALLING LINKERD----------"
    curl -fsL https://run.linkerd.io/install | sh
    export PATH=$PATH:$HOME/.linkerd2/bin
    linkerd check --pre
    linkerd install | kubectl apply -f -
    echo "Linkerd processes are running. Wait 10s"
    sleep 10s
fi

echo "----ANNOTATING WITH LINKERD-----------------------"
kubectl get deploy -o yaml -c cert-manager | linkerd inject - | kubectl apply -f -


kubectl apply -n cert-manager -f clusterissuer-staging.yaml 
kubectl apply -n cert-manager -f clusterissuer-prod.yaml


#!/bin/bash
echo "------------------------------------EXTERNAL-DNS------------------------------------"

####--------CHECKING HELM EXISTENCE------------
output=$(helm version | grep "version.BuildInfo" )
if [[ -n $output ]]
then
    echo " "
else
    echo "-----INSTALLING HELM-------"
    wget https://get.helm.sh/helm-v3.6.0-linux-amd64.tar.gz
    tar xvf helm-v3.6.0-linux-amd64.tar.gz
    sudo mv linux-amd64/helm /usr/local/bin
    rm helm-v3.6.0-linux-amd64.tar.gz
fi

###----CHECKING EXTERNAL-DNS NAMESPACE EXISTENCE--- 
namespace=$(kubectl get ns | grep "external-dns" )
if [[ -n $namespace  ]]
then
    echo "namespace external-dns already exists"
else
    kubectl create ns external-dns
fi

cd ../external-dns ##DIRECTORY IN WHICH THERE ARE CREDENTIALS.JSON AND VALUES.YAML
#------------CREATING SECRET FROM CREDENTIALS.JSON-----
secret=$(kubectl get secret | grep "external-dns" )
if [[ -n $secret ]]
then
    echo "secret external-dns alreay exists"
else
    echo "Creating secrets from credentials.json"
    kubectl create secret generic external-dns --from-file=credentials.json -n external-dns
fi


#--------CHECKING HELM REPO EXISTENCE-------
repo=$(helm repo list | grep bitnami)

if [[ -n $repo  ]]
then
    echo "repo bitnami already exists"
else
    helm repo add bitnami https://charts.bitnami.com/bitnami
fi

#------CHECKING CHART EXISTENCE----
#-----HELM INSTALLING AND UPGRADING PART----
chart=$(helm list -n external-dns | grep "external-dns")
if [[ -n $chart ]]
then  
    echo "-----HELM UPGRADE------"
    helm upgrade external-dns stable/external-dns -f values.yaml
else
    echo "------HELM INSTALL-----"
    helm repo update
    helm upgrade --install external-dns bitnami/external-dns \
    -n external-dns \
    -f values.yaml \
    --atomic \
    --debug \
    --wait 
fi

#-----CHECKING LINKERD EXISTENCE-------
link=$(linkerd version | grep "Client version")
if [[ -n $link]]
then
    echo " "
else
    echo "---------INSTALLING LINKERD----------"
    curl -fsL https://run.linkerd.io/install | sh
    export PATH=$PATH:$HOME/.linkerd2/bin
    linkerd check --pre
    linkerd install | kubectl apply -f -
    echo "Linkerd processes are running. Wait 10s"
    sleep 10s
fi

echo "----ANNOTATING WITH LINKERD-----------------------"
kubectl get deploy -o yaml external-dns  -n external-dns | linkerd inject - | kubectl apply -f -

#!/bin/bash
echo "------------------------------------RELOADER------------------------------------"

###--------checking helm existence----
output=$(helm version | grep "version.BuildInfo" )
if [[ -n $output ]]
then
    echo " "
else
    echo "-----installing HELM"
    wget https://get.helm.sh/helm-v3.6.0-linux-amd64.tar.gz
    tar xvf helm-v3.6.0-linux-amd64.tar.gz
    sudo mv linux-amd64/helm /usr/local/bin
    rm helm-v3.6.0-linux-amd64.tar.gz
fi


#-------checking reloader namespaces existence-
namespace=$(kubectl get ns | grep "reloader" )
echo $namespace
if [[ -n $namespace  ]]
then
    echo "namespace ambassador already exists"
else
    kubectl create ns reloader
fi

#------checking repo stakater existence-
repo=$(helm repo list | grep stakater)

if [[ -n $repo  ]]
then
    echo "repo  already exists"
else
    helm repo add stakater https://stakater.github.io/stakater-charts 
fi
#---------helm installing ------
cd ../reloader
helm repo update 
helm install reloader stakater/reloader \
-n reloader \
--atomic \
--wait
