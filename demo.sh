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
cd reloader
helm repo update 
helm install reloader stakater/reloader \
-n reloader \
--atomic \
--wait
