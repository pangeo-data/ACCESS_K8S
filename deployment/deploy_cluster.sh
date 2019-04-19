#! /bin/bash

# Deploy EKS cluster and EFS storage on AWS for Pangeo JupyterHub
# Will use default profile https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html

# CUSTOMIZE
AWS_DEFAULT_REGION="us-west-2"
AWS_DEFAULT_OUTPUT="json"
CLUSTER_NAME="pangeo"

set -ex

# Create IAM user for EKS cluster management
# https://github.com/weaveworks/eksctl/issues/204
# for now, just stick with admin user
# Create cluster ssh key
KEY_NAME=eks-${CLUSTER_NAME}-${REGION}
aws ec2 create-key-pair --key-name ${KEY_NAME} | jq -r ".KeyMaterial" > eks-${KEY_NAME}.pem
chmod 400 eks-${KEY_NAME}.pem
ssh-keygen -y -f ${KEY_NAME}.pem > eks-${KEY_NAME}.pub

# eksctl will deploy 3 nodes with deployment name in the region specified and allow ssh access using the provided ssh keys
echo "Creating EKS cluster..."
eksctl create cluster --name=${CLUSTER_NAME} --config-file=eksctl_config.yaml

# don't think this is doing anything
#INSTANCE_PROFILE_NAME=$(aws iam list-instance-profiles | jq -r '.InstanceProfiles[].InstanceProfileName' | grep ${DEPLOYMENT_NAME}.nodegroup)
#ROLE_NAME=$(aws iam get-instance-profile --instance-profile-name ${INSTANCE_PROFILE_NAME} | jq -r '.InstanceProfile.Roles[] | .RoleName')
#echo "export ROLE_NAME=${ROLE_NAME}" >> ~/.bash_profile

echo "Created EKS cluster [$CLUSTER_NAME]. Now enabling autoscaling..."
# Now we will enable cluster autoscaling -- please check README.md to make sure you also change the min/max nodes in ASG via the AWS console
AUTOSCALING_GROUP_NAME=$(aws autoscaling describe-auto-scaling-groups | jq -r '.AutoScalingGroups[].Tags[].ResourceId' | grep $CLUSTER_NAME.nodegroup | head -1)

# update ASGs with eksctl command line tool
#aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${AUTOSCALING_GROUP_NAME} --min-size=${MIN_SIZE} --max-size=${MAX_SIZE} --desired-capacity=${DESIRED_SIZE}

NODES_ASG=(${MIN_SIZE}:${MAX_SIZE}:${AUTOSCALING_GROUP_NAME})
sed "s/NODES_ASG_REPLACE/$NODES_ASG/g" ./environment/cluster-autoscaler/cluster_autoscaler.yml > ./environment/cluster-autoscaler/cluster_autoscaler_${DEPLOYMENT_NAME}.yml

kubectl apply -f ./environment/cluster-autoscaler/cluster_autoscaler_${DEPLOYMENT_NAME}.yml

echo "Cluster autoscaling enabled"

kubectl get nodes
