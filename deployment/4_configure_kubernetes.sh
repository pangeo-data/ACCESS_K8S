#!/bin/bash

# these commands are taken from zero2jupyterhub docs
REGION=$(aws configure get region)
EFSID=$(aws efs create-file-system --creation-token newefs --tags "Key=Name,Value=$CLUSTER_NAME" | jq -r ".FileSystemId")

set -e

kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin
kubectl create serviceaccount tiller --namespace=kube-system
kubectl create clusterrolebinding tiller --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller
kubectl --namespace=kube-system patch deployment tiller-deploy --type=json \
      --patch='[{"op": "add", "path": "/spec/template/spec/containers/0/command", "value": ["/tiller", "--listen=localhost:44134"]}]'

# connect efs drive to cluster
helm upgrade --install --namespace kube-system efs-provisioner stable/efs-provisioner \
     --set efsProvisioner.efsFileSystemId=$EFSID \
     --set efsProvisioner.awsRegion=$REGION \

# Change the default storageClass (for now, given there's a bug in efs provisioner, this needs to be two steps).
kubectl patch storageclass gp2 -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "false"}}}' || true
kubectl patch storageclass efs -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}' || true
