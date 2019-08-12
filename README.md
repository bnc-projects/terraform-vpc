# terraform-vpc
A terraform module to create a VPC based on best practices. This module will deploy across all availability zones up to a maximum of 6 availability zones.

Each subnet will have 2048 IPv4 addresses, with 2043 usable as 5 are reserved by AWS.

See [Amazon Virtual Private Cloud User Guide](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html) for more information.

## Examples

## VPC with NAT Gateways
```
module "vpc" {
  source             = "git::https://github.com/bnc-projects/terraform-vpc.git?ref=1.0.0"
  cidr_block         = 10.0.0.0/16
  enable_nat_gateway = true
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| assign_generated_ipv6_cidr_block | Requests an Amazon-provided IPv6 CIDR block with a /56 prefix length for the VPC | boolean | `true` | no |
| cidr_block | The CIDR block for the VPC | string | `0.0.0.0/0` | yes |
| database_inbound_acl_rules | Database subnets inbound network ACLs | list(map(string)) | `[]` | no |
| database_outbound_acl_rules | Database subnets outbound network ACLs | list(map(string)) | `[]` | no |
| enable_dns_hostnames | Enable DNS hostnames in the VPC | boolean | `false` | no |
| enable_dns_support | Enable DNS support in the VPC | list(string) | `true` | no |
| enable_nat_gateway | Provision NAT Gateways for the private networks | boolean | `false` | no |
| instance_tenancy | Tenancy option for instances launched into the VPC | string | `default` | no |
| name | The name to use when tagging resources | string | `-` | no |
| public_inbound_acl_rules | Public subnets inbound network ACLs | list(map(string)) | `[]` | no |
| public_outbound_acl_rules | Public subnets outbound network ACLs | list(map(string)) | `[]` | no |
| private_inbound_acl_rules | Private subnets inbound network ACLs | list(map(string)) | `[]` | no |
| private_outbound_acl_rules | Private subnets outbound network ACLs | list(map(string)) | `[]` | no |
| tags | Tags to apply to the resources | map(string) | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| public_subnets | List of all the outputs for the public subnets |
| private_subnets | List of all the outputs for the private subnets  |
| database_subnets | List of all the outputs for the database subnets |
| nat_gateway_ips | The list of public IP addresses associated with NAT gateways |
| vpc | The outputs for the VPC  |