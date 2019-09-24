# ACCESS_K8S
Configs and scripts for building kubernetes clusters managed by the Pangeo NASA ACCESS Project. Much of building the cluster uses [eksctl](https://github.com/weaveworks/eksctl) following the steps outlined here: [https://eksworkshop.com/](https://eksworkshop.com/)

Running this deploy script will setup a Kubernetes Cluster on AWS that is needed to deploy a Pangeo JupyerHub. Once this cluster is setup, the JupyterHub configuration and deployment happens here https://github.com/pangeo-data/pangeo-cloud-federation).

**Last update: 04/2019**


### Prerequisites

* Set up an AWS account and create an IAM user to deploy clusters (see `1_create_iam_user.sh`)

* Scripts in this repository automate steps outlined in Zero2JupyterHub for deploying a kubernetes cluster with AWS EKS
https://zero-to-jupyterhub.readthedocs.io/en/latest/amazon/step-zero-aws-eks.html#

* Scripts require `awscli`, `kubectl` and `aws-iam-authenticator` and `eksctl` to run


### Customize

* Change the AWS account number, cluster name, region also
* modify `eksctl_config.yaml` if you want different settings


### Deploy

`./deployment/deploy_cluster.sh`


### What exactly does this setup and what does it cost?

Exact pricing of Cloud computing infrastructure is challenging, but here are some ballpark figures

This script will setup an EKS cluster that currently costs $0.20/hr.  **So at a minimum you'll be paying $144/month ($1752/yr)**. On top of that, your price will depend on the type of nodes ([EC2 instances](https://aws.amazon.com/ec2/pricing/)) you allow for Hub users and Dask workers and the number of users and storage. The cluster autoscales, so if nobody uses it, you pay the minimum.

* In short, it's pretty easy to spend between $350-$800 per month with typical usage.

* JupyterHub pods run continuously on m5.large nodes (3 by default in different availability zone in the cluster region). These cost $0.096/hr so we spend $207/month ($2522/yr).

* Assume 1 person uses the cluster 24 hours a week without spinning up dask workers and keeps 100 Gb of data in their home directory. Their notebook runs on a `m5.2xlarge` instance by default, costing $0.384/hr (so $9.21/month). [standard EFS storage costs](https://aws.amazon.com/efs/pricing/) are $0.30/Gb-month, which for this case equates to $30/mo.

* Assume 1 person is using the dask kubernetes cluster extensively (24 hours/week) to run distributed computations. Dask workers by default run on `r5.2xlarge` instances (64Gb distributed memory), which cost $0.504/hour. In addition to the above cost, we'd add $12.10/mo.

* Assume you are running a workshop with 50 people using the cluster for 48 hours per week, 24 hours of dask worker usage, and each person keeps 10Gb in their home directories. Everyone will also be accessing 1 Tb of common data on S3. The S3 storage costs $0.023/GB, so that will be $23. Things are setup to keep 2 users per node, so we estimate ($0.384/hr*48*25 + $3.00/4*50 + $12.10/4*25) ~ $600.
