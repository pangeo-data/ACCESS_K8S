#! /bin/bash

export AWS_DEFAULT_PROFILE=circleci
# NOTE: should be 1.3.8 for kubernetes 1.11, or 1.12.3 for kuberenets 1.12
AUTOSCALER_VERSION="v1.12.3"
AUTOSCALER_KEY="k8s.io/cluster-autoscaler/node-template/label/alpha.eksctl.io/nodegroup-name"
REGION=$(aws configure get region)
CLUSTER_NAME=pangeo-nasa

echo "Enabling autoscaling on EKS cluster [$CLUSTER_NAME]..."

LABEL=user-notebook
ASG=$(aws autoscaling describe-auto-scaling-groups --query 'AutoScalingGroups[?contains(AutoScalingGroupName, `user-notebook`)]' | jq -r ".[].AutoScalingGroupName")
MIN=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG | jq -r ".AutoScalingGroups[].MinSize")
MAX=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG | jq -r ".AutoScalingGroups[].MaxSize")
ASG_NOTEBOOK=(${MIN}:${MAX}:${ASG})
AUTOSCALER_TAG="ResourceId=$ASG,ResourceType=auto-scaling-group,Key=$AUTOSCALER_KEY,Value=$LABEL,PropagateAtLaunch=true"
aws autoscaling create-or-update-tags --tags $AUTOSCALER_TAG

LABEL=dask-worker
ASG=$(aws autoscaling describe-auto-scaling-groups --query 'AutoScalingGroups[?contains(AutoScalingGroupName, `dask-worker`)]' | jq -r ".[].AutoScalingGroupName")
MIN=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG | jq -r ".AutoScalingGroups[].MinSize")
MAX=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG | jq -r ".AutoScalingGroups[].MaxSize")
ASG_DASK=(${MIN}:${MAX}:${ASG})
AUTOSCALER_TAG="ResourceId=$ASG,ResourceType=auto-scaling-group,Key=$AUTOSCALER_KEY,Value=$LABEL,PropagateAtLaunch=true"
aws autoscaling create-or-update-tags --tags $AUTOSCALER_TAG

sed -e "s/CHANGE_AUTOSCALER_VERSION/$AUTOSCALER_VERSION/g" -e "s/CHANGE_REGION/$REGION/g" -e "s/CHANGE_NODEGROUP_NOTEBOOK/$ASG_NOTEBOOK/g" -e "s/CHANGE_NODEGROUP_DASK/$ASG_DASK/g"  ./templates/template-cluster-autoscaler.yaml > cluster-autoscaler.yaml

# Autoscaling to 0 requires special iam policy for hub NodeInstanceRole
# messy, use aws cli instead?
HUB_ROLE=$(eksctl utils describe-stacks --name pangeo-nasa | grep eksctl-pangeo-nasa-nodegroup-hub-NodeInstanceRole --color=never | cut -d'/' -f2 | tr -d '"')
aws iam put-role-policy --role-name $HUB_ROLE --policy-name autoscaler --policy-document file://templates/template-autoscaler-permissions.json
#aws iam create-policy --policy-name cluster-autoscaler --policy-document file://templates/template-autoscaler-permissions.json

echo "Applying autoscaler configuration cluster-autoscaler.yaml..."
kubectl apply -f cluster-autoscaler.yaml

echo "Cluster autoscaling enabled!"
