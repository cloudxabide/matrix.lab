#!/bin/bash

# If a pager is available, the script stops waiting to page through output
AWS_PAGER=""


OUTPUT="table"
REGION="us-east-1"

export AWS_PAGER OUTPUT REGION

aws configure set region $REGION
aws configure set output $OUTPUT

user_info() {
aws sts get-caller-identity
aws iam get-user
aws iam list-groups
aws iam list-roles
}

aws_infra_info() {
echo "# VPC overview"
aws ec2 describe-vpcs --region $REGION --query 'Vpcs[*].[CidrBlock,Tags[?Key==`Name`].Value|[0]]' --output $OUTPUT

echo "# NAT Gateways (natgw) and EIPs"
aws ec2 describe-nat-gateways --region $REGION --query "NatGateways[*].NatGatewayAddresses[*]" --output $OUTPUT

echo "# ELBs (elbv2)"
aws elbv2 describe-load-balancers --region $REGION --output $OUTPUT --query "LoadBalancers[*].DNSName"
# NOTE - Need to figure this out...
# aws elbv2 describe-load-balancers --region $REGION --output $OUTPUT --query "LoadBalancers[*].[DNSName,AvailabilityZones]"

echo "# Subnet and their CIDR Blocks"
aws ec2 describe-subnets --region $REGION --query 'Subnets[*].[CidrBlock,SubnetId,Tags[?Key==`Name`].Value|[0]]' --output $OUTPUT

echo "# Availability Zones in-use"
aws ec2 describe-availability-zones --query "AvailabilityZones[*].[ZoneName]" --output $OUTPUT

echo "# Hosted Zones"
aws route53 list-hosted-zones --query "HostedZones[*].Name" --output $OUTPUT

echo "# EC2 Instance Info (with Networking)"
aws ec2 describe-instances --region $REGION --query "Reservations[*].Instances[*].{name: Tags[?Key=='Name'] | [0].Value, IP: PrivateIpAddress, Subnet: SubnetId}" --output table --color off
}

ocp_info() {
echo "# OCP Status"
echo "# serviceNetwork is implied in the output"
oc status

echo "# Host Subnets"
oc get hostsubnets

echo "# Networking | clusterNetwork"
oc  get network.config/cluster -o jsonpath='{.spec.clusterNetwork},{"\n"}'

echo "# Networking | serviceNetwork"
 oc  get network.config/cluster -o jsonpath='{.spec.serviceNetwork},{"\n"}'
}

aws_infra_info
ocp_info
