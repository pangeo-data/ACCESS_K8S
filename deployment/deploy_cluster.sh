#! /bin/bash

set -ex

DEPLOYMENT_NAME="pangeo-nasa"
REGION="us-west-2"
PEM_KEY="amandatan-pangeo-testmachine"
MIN_SIZE="2"
MAX_SIZE="8"
DESIRED_SIZE="3"

# eksctl will deploy 3 nodes with deployment name in the region specified and allow ssh access using the provided ssh keys
echo "Creating EKS cluster..."
eksctl create cluster --name=${DEPLOYMENT_NAME} --ssh-access  --ssh-public-key=${PEM_KEY} --region=${REGION} --nodes=3 --node-ami=auto

INSTANCE_PROFILE_NAME=$(aws iam list-instance-profiles | jq -r '.InstanceProfiles[].InstanceProfileName' | grep ${DEPLOYMENT_NAME}.nodegroup)
ROLE_NAME=$(aws iam get-instance-profile --instance-profile-name ${INSTANCE_PROFILE_NAME} | jq -r '.InstanceProfile.Roles[] | .RoleName')
echo "export ROLE_NAME=${ROLE_NAME}" >> ~/.bash_profile

echo "Created EKS cluster [$DEPLOYMENT_NAME]. Now enabling autoscaling..."
# Now we will enable cluster autoscaling -- please check README.md to make sure you also change the min/max nodes in ASG via the AWS console
AUTOSCALING_GROUP_NAME=$(aws autoscaling describe-auto-scaling-groups | jq -r '.AutoScalingGroups[].Tags[].ResourceId' | grep $DEPLOYMENT_NAME.nodegroup | head -1)

aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${AUTOSCALING_GROUP_NAME} --min-size=${MIN_SIZE} --max-size=${MAX_SIZE} --desired-capacity=${DESIRED_SIZE}

NODES_ASG=(${MIN_SIZE}:${MAX_SIZE}:${AUTOSCALING_GROUP_NAME})
sed "s/NODES_ASG_REPLACE/$NODES_ASG/g" ./environment/cluster-autoscaler/cluster_autoscaler.yml > ./environment/cluster-autoscaler/cluster_autoscaler_${DEPLOYMENT_NAME}.yml

kubectl apply -f ./environment/cluster-autoscaler/cluster_autoscaler_${DEPLOYMENT_NAME}.yml

echo "Cluster autoscaling enabled"

kubectl get nodes
