# ACCESS_K8S
Configs and scripts for building kubernetes clusters managed by the Pangeo NASA ACCESS Project. Much of building the cluster uses [eksctl](https://github.com/weaveworks/eksctl) following the steps outlined here:[https://eksworkshop.com/] (https://eksworkshop.com/)

Steps to building your own cluster on AWS using our config. scripts


**Prerequisites**
Set up an AWS account and obtain the appropriate AWS credentials. 

[Create an Amazon EC2 key pair](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#having-ec2-create-your-key-pair) to enable ssh access into a node on the cluster (needed for mounting the EFS)

[Install kubectl](https://eksworkshop.com/prerequisites/k8stools/) 
[Install eksctl](https://eksworkshop.com/eksctl/prerequisites/)  
 

```
cd ./ACCESS_K8S/deployment

```
Change the variables for DEPLOYMENT_NAME, REGION, PEM_KEY, MIN_SIZE, MAX_SIZE and DESIRED_CAPACITY as necessaryy

```

bash ./deploy_cluster.sh
 
```
 
Follow with [cloud-federation](https://github.com/pangeo-data/pangeo-cloud-federation). 
