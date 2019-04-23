#! /bin/bash

# Assumes you have already configured a 'circleci' user and awscli profile from 1_create_iam_user.sh
export AWS_DEFAULT_PROFILE=circleci
REGION=$(aws configure get region)
CLUSTER_NAME=pangeo-nasa

echo "Using AWS profile=$AWS_DEFAULT_PROFILE, region=$REGION"

set -ex
# Create cluster ssh key
KEY_NAME=eks-${CLUSTER_NAME}-${REGION}
echo "Creating key pair $KEY_NAME..."
aws ec2 create-key-pair --key-name ${KEY_NAME} | jq -r ".KeyMaterial" > ${KEY_NAME}.pem
chmod 400 ${KEY_NAME}.pem
ssh-keygen -y -f ${KEY_NAME}.pem > ${KEY_NAME}.pub

# Creating a new ECR repository
echo "Creating new ECR repository..."
aws ecr create-repository --repository-name ${CLUSTER_NAME}

# Create configuration file from template
echo "Creating eksctl-config.yaml configuration file..."
sed -e "s/CHANGE_CLUSTER_NAME/$CLUSTER_NAME/g" -e "s/CHANGE_REGION/$REGION/g" -e "s/CHANGE_PUBLICKEY/${KEY_NAME}.pub/g" ./templates/template-eksctl-config.yaml > eksctl-config.yaml

# Create EKS cluster
echo "Creating EKS cluster '$CLUSTER_NAME'..."
eksctl create cluster --config-file=eksctl-config.yaml

# Create EFS volume in same VPC as cluster
echo "Created EKS cluster [$CLUSTER_NAME]. Now adding EFS volume in same VPC..."
VPC=$(aws eks describe-cluster --name ${CLUSTER_NAME} | jq -r ".cluster.resourcesVpcConfig.vpcId")
SUBNETS_PUBLIC=($(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC" "Name=tag:Name,Values=*PublicRouteTable*" | jq -r ".RouteTables[].Associations[].SubnetId"))
SG_NODES_SHARED=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC" "Name=tag:Name,Values=*ClusterSharedNodeSecurityGroup*" | jq -r ".SecurityGroups[].GroupId")

EFSID=$(aws efs create-file-system --creation-token newefs --tags "Key=Name,Value=$CLUSTER_NAME" | jq -r ".FileSystemId")
for i in "${SUBNETS_PUBLIC[@]}"
do
	aws efs create-mount-target --file-system-id $EFSID --subnet-id $i --security-groups $SG_NODES_SHARED
done


echo "Done! to delete this cluster run 'eksctl delete cluster --name ${CLUSTER_NAME}'"
