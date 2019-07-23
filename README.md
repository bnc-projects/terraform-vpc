# terraform-vpc
A terraform module to create a VPC based on best practices. This module will deploy across all availability zones up to a maximum of 6 availability zones.

Each subnet will have 2048 IPv4 addresses, with 2043 usable as 5 are reserved by AWS.

See [Amazon Virtual Private Cloud User Guide](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html) for more information.