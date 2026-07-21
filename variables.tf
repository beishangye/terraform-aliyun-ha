provider "alicloud" {
  region = "cn-hangzhou"
}

# ==================== 变量定义 ====================
variable "vpc_name" {
  default = "ha-vpc"
}

variable "vpc_cidr" {
  default = "172.16.0.0/16"
}

# Web 实例的可用区
variable "az_web1" {
  default = "cn-hangzhou-h"
}

variable "az_web2" {
  default = "cn-hangzhou-i"
}

# Web 交换机网段
variable "vswitch_web1_cidr" {
  default = "172.16.1.0/24"
}

variable "vswitch_web2_cidr" {
  default = "172.16.2.0/24"
}

# RDS 交换机网段（可用区由 data 动态决定）
variable "vswitch_rds_cidr" {
  default = "172.16.3.0/24"
}

variable "ecs_image" {
  default = "ubuntu_22_04_x64_20G_alibase_20260615.vhd"
}

variable "ecs_type" {
  default = "ecs.e-c1m1.large"
}

variable "ecs_name" {
  default = "ha-ecs"
}

variable "ecs_password" {
  default   = "yourpassword"
  sensitive = true
}

variable "slb_name" {
  default = "ha-slb"
}

variable "sg_name" {
  default = "ha-sg"
}

variable "my_ip" {
  default = "0.0.0.0/0" # 建议改为您自己的公网 IP，如 "113.xx.xx.xx/32"
}

# RDS 变量
variable "rds_name" {
  default = "ha-mysql"
}

variable "rds_db_name" {
  default = "app_database"
}

variable "rds_account_name" {
  default = "app_user"
}

variable "rds_account_password" {
  default   = "yourpassword"
  sensitive = true
}

# OSS 变量
variable "oss_bucket_name_prefix" {
  default = "ha-oss-bucket"
}