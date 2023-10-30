terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
}


# tạo VPC

      resource "aws_vpc" "my_vpc_1" {
        cidr_block           = "10.0.0.0/16"
        enable_dns_hostnames = true

        tags = {
          "Name" = "VLU_VPC"
        }
      }


# tạo subnet 
        variable "name_pri_sub" {
        default = ["VLU_private-subnet-01","VLU_private-subnet-02","VLU_private-subnet-03","VLU_private-subnet-04"]
        type = list(string)
        }

        variable "name_pub_sub" {
        default = ["VLU_public-subnet-01","VLU_public-subnet-02"]
        type = list(string)
        }


        locals {
          private = ["10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
          public = ["10.0.1.0/24", "10.0.2.0/24"]
          zone   = ["ap-southeast-1a", "ap-southeast-1b"]
        }

        resource "aws_subnet" "private_subnet" {
          count = length(local.private)
          vpc_id            = aws_vpc.my_vpc_1.id
          cidr_block        = local.private[count.index]
          availability_zone = local.zone[count.index % length(local.zone)]

          tags = {
            "Name" = var.name_pri_sub[count.index]
          }
        }

        resource "aws_subnet" "public_subnet" {
          count = length(local.public)
          vpc_id            = aws_vpc.my_vpc_1.id
          cidr_block        = local.public[count.index]
          availability_zone = local.zone[count.index % length(local.zone)]
         
              tags = {
            "Name" = var.name_pub_sub[count.index]
          }
        }

#tạo security
        resource "aws_security_group" "SG" {
          vpc_id = aws_vpc.my_vpc_1.id
          name   = "Web Server Security Group"
          ingress {
            protocol    = "tcp"
            from_port   = 80
            to_port     = 80
            cidr_blocks = ["0.0.0.0/0"]
          }
          egress {
            protocol    = "tcp"
            from_port   = 0
            to_port     = 0
            cidr_blocks = ["0.0.0.0/0"]
          }
           tags = {
                    "Name" = "VLU_securitygroup"
        }
        }

# # tạo internet gateway
        resource "aws_internet_gateway" "ig" {
          vpc_id = aws_vpc.my_vpc_1.id

          tags = {
            "Name" = "VLU_ig1"
          }
        }

#tạo natgateway

        resource "aws_eip" "nat" {
          vpc = true
        }

        resource "aws_nat_gateway" "public" {
          depends_on = [aws_internet_gateway.ig]
          allocation_id = aws_eip.nat.id
          subnet_id     = aws_subnet.public_subnet[0].id
          tags = {
            Name = "Public NAT"
          }
        }

# #tạo routetable
        resource "aws_route_table" "public" {
          vpc_id = aws_vpc.my_vpc_1.id

          route {
            cidr_block = "0.0.0.0/0"
            gateway_id = aws_internet_gateway.ig.id
          }
        
          tags = {
            "Name" = "public"
          }
        }


        resource "aws_route_table" "private" {
                  vpc_id = aws_vpc.my_vpc_1.id

                  route {
                    cidr_block = "0.0.0.0/0"
                    gateway_id = aws_nat_gateway.public.id
                  }

                  tags = {
                    "Name" = "private"
                  }
                }

resource "aws_route_table_association" "public_association" {
     # subnet_id = aws_subnet.public_subnet[count.index]
     for_each       = { for k, v in aws_subnet.public_subnet : k => v }
    subnet_id      = each.value.id
      route_table_id = aws_route_table.public.id
  }

  resource "aws_route_table_association" "private_association" {
     # subnet_id = aws_subnet.private_subnet[count.index]\
     for_each       = { for k, v in aws_subnet.private_subnet : k => v }
    subnet_id      = each.value.id
      route_table_id = aws_route_table.private.id
  }

