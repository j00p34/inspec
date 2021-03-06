# Contains resources and outputs related to testing the aws_eks_cluster resources.

#======================================================#
#                    EKS variables
#======================================================#

variable "region" {
  default = "us-west-2"
}

variable "map_accounts" {
  description = "Additional AWS account numbers to add to the aws-auth configmap."
  type        = "list"

  default = [
    "777777777777",
    "888888888888",
  ]
}

variable "map_roles" {
  description = "Additional IAM roles to add to the aws-auth configmap."
  type        = "list"

  default = [
    {
      role_arn = "arn:aws:iam::66666666666:role/role1"
      username = "role1"
      group    = "system:masters"
    },
  ]
}

variable "map_users" {
  description = "Additional IAM users to add to the aws-auth configmap."
  type        = "list"

  default = [
    {
      user_arn = "arn:aws:iam::66666666666:user/user1"
      username = "user1"
      group    = "system:masters"
    },
    {
      user_arn = "arn:aws:iam::66666666666:user/user2"
      username = "user2"
      group    = "system:masters"
    },
  ]
}

#======================================================#
#                    EKS Cluster
#======================================================#

terraform {
  required_version = "= 0.11.8"
}

data "aws_availability_zones" "available" {}

locals {
  cluster_name = "test-eks-inspec-${terraform.env}"

  worker_groups = [
    {
      instance_type                 = "t2.small"
      additional_userdata           = "echo foo bar"
      subnets                       = "${join(",", module.vpc.private_subnets)}"
      additional_security_group_ids = "${aws_security_group.worker_group_mgmt_one.id},${aws_security_group.worker_group_mgmt_two.id}"
    },
  ]
  tags = {
    Environment = "test-eks-${terraform.env}"
  }
}

resource "aws_security_group" "worker_group_mgmt_one" {
  name_prefix = "worker_group_mgmt_one-${terraform.env}"
  description = "SG to be applied to all *nix machines"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
    ]
  }
}

resource "aws_security_group" "worker_group_mgmt_two" {
  name_prefix = "worker_group_mgmt_two-${terraform.env}"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "192.168.0.0/16",
    ]
  }
}

resource "aws_security_group" "all_worker_mgmt" {
  name_prefix = "all_worker_management-${terraform.env}"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16",
    ]
  }
}

module "vpc" {
  source             = "terraform-aws-modules/vpc/aws"
  version            = "1.14.0"
  name               = "test-vpc"
  cidr               = "10.0.0.0/16"
  azs                = ["${data.aws_availability_zones.available.names[0]}", "${data.aws_availability_zones.available.names[1]}", "${data.aws_availability_zones.available.names[2]}"]
  private_subnets    = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_nat_gateway = false
  tags               = "${merge(local.tags, map("kubernetes.io/cluster/${local.cluster_name}", "shared"))}"
}

output "vpc_id" {
  value = "${module.vpc.vpc_id}"
}

output "vpc_private_subnets" {
  value = "${module.vpc.private_subnets}"
}

output "vpc_public_subnets" {
  value = "${module.vpc.public_subnets}"
}

module "eks" {
  source                               = "terraform-aws-modules/eks/aws"
  version                              = "1.6.0"
  cluster_name                         = "${local.cluster_name}"
  subnets                              = ["${module.vpc.private_subnets}"]
  tags                                 = "${local.tags}"
  vpc_id                               = "${module.vpc.vpc_id}"
  worker_groups                        = "${local.worker_groups}"
  worker_group_count                   = "1"
  worker_additional_security_group_ids = ["${aws_security_group.all_worker_mgmt.id}"]
  map_roles                            = "${var.map_roles}"
  map_users                            = "${var.map_users}"
  map_accounts                         = "${var.map_accounts}"
  manage_aws_auth                      = false
}

output "eks_cluster_id" {
  value = "${module.eks.cluster_id}"
}

output "eks_cluster_name" {
  value = "${module.eks.cluster_id}"
}

output "cluster_security_group_id" {
  value = "${module.eks.cluster_security_group_id}"
}

output "worker_security_group_id" {
  value = "${module.eks.worker_security_group_id}"
}

output "cluster_endpoint" {
  value = "${module.eks.cluster_endpoint}"
}

output "eks_cluster_certificate" {
  value = "${module.eks.cluster_certificate_authority_data}"
}
