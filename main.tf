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
          "Name" = "vpc1"
        }
      }

# resource "aws_vpc" "my_vpc_2" {
#   cidr_block           = "20.0.0.0/16"
#   enable_dns_hostnames = true

#   tags = {
#     "Name" = "vpc2"
#   }
# }


# tạo subnet cho vcp 1
        variable "name_pri_sub" {
        default = ["private-subnet-01","private-subnet-02","private-subnet-03","private-subnet-04"]
        type = list(string)
        }

        variable "name_pub_sub" {
        default = ["public-subnet-01","public-subnet-02"]
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

#         # tạo subnet cho vpc2 

#         # locals {
#         #   public2 = ["20.0.1.0/24"]
#         #   zone2   = ["us-east-1a"]
#         # }
#         # resource "aws_subnet" "public_subnet_2" {
#         #   vpc_id            = aws_vpc.my_vpc_2.id
#         #   cidr_block        = local.public2.id
#         #   availability_zone = local.zone2.id

#         #   tags = {
#         #     "Name" = "public-subnet_vcp2"
#         #   }
#         # }


# # tạo internet gateway
        resource "aws_internet_gateway" "ig" {
          vpc_id = aws_vpc.my_vpc_1.id

          tags = {
            "Name" = "ig1"
          }
        }

# resource "aws_internet_gateway" "ig2" {
#   vpc_id = aws_vpc.my_vpc_2.id

#   tags = {
#     "Name" = "ig2"
#   }
# }


# #tạo routetable
        resource "aws_route_table" "public1" {
          vpc_id = aws_vpc.my_vpc_1.id

          route {
            cidr_block = "0.0.0.0/0"
            gateway_id = aws_internet_gateway.ig.id
          }

          tags = {
            "Name" = "public"
          }
        }


# resource "aws_route_table" "public2" {
#   vpc_id = aws_vpc.my_vpc_2.id

#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.ig2.id
#   }

#   tags = {
#     "Name" = "public"
#   }
# }


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



#tạo loadbalacing
        resource "aws_security_group" "webapp" {
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
        }



# tạo ec2
      resource "aws_instance" "web" {
        ami                    = "ami-0b89f7b3f054b957e"
        instance_type          = "t2.micro"
        availability_zone      = local.zone[1]
        vpc_security_group_ids = [aws_security_group.webapp.id]
        subnet_id              = aws_subnet.public_subnet[1].id
        associate_public_ip_address = true
        tags = {
          "Name" = "web"
        }
      }

#autoscaling



