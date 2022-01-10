#!/bin/bash

####--------CHECKING HELM EXISTENCE------------


if  ! command -v helm &> /dev/null 
then
    echo "-------------------------------------------------------------- "
    echo "-------------------------------------------------------------- "
    echo "-----INSTALLING HELM------------------------------------------"
    wget https://get.helm.sh/helm-v3.6.0-linux-amd64.tar.gz
    tar xvf helm-v3.6.0-linux-amd64.tar.gz
    sudo mv linux-amd64/helm /usr/local/bin
    rm helm-v3.6.0-linux-amd64.tar.gz
fi

#-----CHECKING LINKERD EXISTENCE-------

if  ! command -v linkerd &> /dev/null 
then
    echo "-------------------------------------------------------------- "
    echo "-------------------------------------------------------------- "
    echo "---------INSTALLING LINKERD----------"
    curl -fsL https://run.linkerd.io/install | sh
    export PATH=$PATH:$HOME/.linkerd2/bin
    linkerd check --pre
    linkerd install | kubectl apply -f -
    echo "Linkerd processes are running. Wait 20s"
    sleep 20s
fi








###----CHECKING EXTERNAL-DNS NAMESPACE EXISTENCE--- 


echo "----------------------------------------------------------------------------------- "
echo "-----------------------------------------------------------------------------------"
echo "------------------------------------EXTERNAL-DNS------------------------------------"
if [[ -n $(kubectl get ns | grep "external-dns" )  ]]
then
    echo "namespace external-dns already exists"
else
    kubectl create ns external-dns
fi

cd external-dns ##DIRECTORY IN WHICH THERE ARE CREDENTIALS.JSON AND VALUES.YAML
#-----------CREATING SECRET FROM CREDENTIALS.JSON-----

if [[ -n $(kubectl get secret -n external-dns | grep "external-dns" ) ]]
then
    echo "secret external-dns alreay exists"
else
    echo "Creating secrets from credentials.json"
    kubectl create secret generic external-dns --from-file=credentials.json -n external-dns
fi


#--------CHECKING HELM REPO EXISTENCE-------


if [[ -n $(helm repo list | grep bitnami)  ]]
then
    echo "repo bitnami already exists"
else
    helm repo add bitnami https://charts.bitnami.com/bitnami
fi

#------CHECKING CHART EXISTENCE----
#-----HELM INSTALLING AND UPGRADING PART----

if [[ -n $(helm list -n external-dns | grep "external-dns") ]]
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



echo "-------------------------------------------------------------- "
echo "-------------------------------------------------------------- "
echo "----ANNOTATING WITH LINKERD------------------------------------"
export PATH=$PATH:$HOME/.linkerd2/bin
kubectl get deploy -o yaml external-dns  -n external-dns | linkerd inject - | kubectl apply -f -








echo "-------------------------------------------------------------- ---------------------"
echo "----------------------------------------------------------------------------------- "
echo "------------------------------------CERT-MANAGER------------------------------------"



###----CHECKING CERT-MANAGER NAMESPACE EXISTENCE--- 


if [[ -n $(kubectl get ns | grep "cert-manager" )  ]]
then
    echo "namespace cert-manager already exists"
else
    kubectl create ns cert-manager
fi


cd ../cert-manager ##DIRECTORY IN WHICH THERE ARE CREDENTIALS.JSON AND VALUES.YAML
#------------CREATING SECRET FROM CREDENTIALS.JSON-----

if [[ -n $(kubectl get secret -n cert-manager | grep "prod-cert-manager" ) ]]
then
    echo "secret prod-cert-manager alreay exists"
else
    kubectl create secret generic prod-cert-manager --from-file=credentials.json -n cert-manager
fi

kubectl apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.13/deploy/manifests/00-crds.yaml

#--------CHECKING HELM REPO EXISTENCE-------

if [[ -n $(helm repo list | grep jetstack)  ]]
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


echo "-------------------------------------------------------------- "
echo "-------------------------------------------------------------- "
echo "----ANNOTATING WITH LINKERD-----------------------"
export PATH=$PATH:$HOME/.linkerd2/bin
kubectl get deploy -o yaml -n cert-manager | linkerd inject - | kubectl apply -f -


kubectl apply -n cert-manager -f clusterissuer-staging.yaml 
kubectl apply -n cert-manager -f clusterissuer-prod.yaml







echo "-------------------------------------------------------------- "
echo "-------------------------------------------------------------- "
echo "------------------------------------AMBASSADOR------------------------------------"



###----CHECKING CERT-MANAGER NAMESPACE EXISTENCE--- 


if [[ -n $(kubectl get ns | grep "ambassador" )  ]]
then
    echo "namespace ambassador already exists"
else
    kubectl create ns ambassador
fi
kubectl apply -f https://www.getambassador.io/yaml/aes-crds.yaml 





#--------CHECKING HELM REPO EXISTENCE-------


if [[ -n $(helm repo list | grep datawire)  ]]
then
    echo "repo  already exists"
else
    helm repo add datawire https://www.getambassador.io 
fi
#-----HELM INSTALLING AND UPGRADING PART----
cd ../ambassador-aes1

helm repo update
helm upgrade --install ambassador-aes1 datawire/ambassador -n ambassador \
-f values.yaml \
--atomic \
--timeout 10m \
--debug

kubectl apply -f global.yaml -f tls.yaml





echo "-------------------------------------------------------------- "
echo "-------------------------------------------------------------- "
echo "------------------------------------RELOADER------------------------------------"




#-------checking reloader namespaces existence-


if [[ -n $(kubectl get ns | grep "reloader" )  ]]
then
    echo "namespace ambassador already exists"
else
    kubectl create ns reloader
fi

#------checking repo stakater existence-


if [[ -n $(helm repo list | grep stakater) ]]
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

