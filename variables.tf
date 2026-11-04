# ============================================================
# 变量定义
#
# 设计原则：
#   1. 凡是"决定资源长什么样"的参数（可用区、规格、存储），
#      一律写成显式变量，不用 data 源自动推断。
#      原因：data 源每次 plan 都重新求值，库存变化会让关键字段漂移，
#      而 RDS 的 zone_id / instance_type / instance_storage 都是
#      ForceNew —— 一次库存变动就可能触发"删库重建"。
#   2. 密码类变量没有 default：宁可 apply 时让你填，也不要
#      悄悄用 "yourpassword" 上线。
# ============================================================

# ---------- 全局 ----------

variable "region" {
  description = "阿里云地域。注意：下面的可用区必须属于该地域。"
  type        = string
  default     = "cn-hangzhou"
}

variable "project_name" {
  description = "项目名，用于统一打标签（成本分摊 / 批量查找资源）"
  type        = string
  default     = "ha-demo"
}

variable "environment" {
  description = "环境标识，用于统一打标签"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment 只能是 dev / staging / prod。"
  }
}

# ---------- 网络 ----------

variable "vpc_name" {
  description = "VPC 名称"
  type        = string
  default     = "ha-vpc"
}

variable "vpc_cidr" {
  description = "VPC 网段"
  type        = string
  default     = "172.16.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr 必须是合法的 CIDR，例如 172.16.0.0/16。"
  }
}

variable "az_web1" {
  description = "Web01 部署可用区"
  type        = string
  default     = "cn-hangzhou-h"
}

variable "az_web2" {
  description = "Web02 部署可用区（必须与 az_web1 不同，否则跨 AZ 高可用失效）"
  type        = string
  default     = "cn-hangzhou-i"

  validation {
    condition     = var.az_web2 != var.az_web1
    error_message = "az_web2 必须与 az_web1 不同，否则两台 ECS 在同一可用区，跨 AZ 高可用名存实亡。"
  }
}

variable "az_rds" {
  description = "RDS 部署可用区（显式指定，避免 data 源漂移触发实例替换）"
  type        = string
  default     = "cn-hangzhou-i"
}

variable "vswitch_web1_cidr" {
  description = "Web01 交换机网段"
  type        = string
  default     = "172.16.1.0/24"
}

variable "vswitch_web2_cidr" {
  description = "Web02 交换机网段"
  type        = string
  default     = "172.16.2.0/24"
}

variable "vswitch_rds_cidr" {
  description = "RDS 交换机网段"
  type        = string
  default     = "172.16.3.0/24"
}

# ---------- 访问控制 ----------

variable "my_ip" {
  description = "允许 SSH 访问的来源 CIDR（填你自己的公网 IP，如 203.0.113.10/32）"
  type        = string

  validation {
    condition     = var.my_ip != "0.0.0.0/0" && can(cidrhost(var.my_ip, 0))
    error_message = "必须填写具体来源网段（例如 203.0.113.10/32），不允许 0.0.0.0/0 把 22 端口开到全网。"
  }
}

variable "sg_name" {
  description = "安全组名称"
  type        = string
  default     = "ha-sg"
}

# ---------- ECS ----------

variable "ecs_name" {
  description = "ECS 实例名前缀"
  type        = string
  default     = "ha-ecs"
}

variable "ecs_type" {
  description = "ECS 实例规格"
  type        = string
  default     = "ecs.e-c1m1.large"
}

variable "ecs_image" {
  description = "ECS 镜像 ID。镜像会下线，apply 报错时到 ECS 控制台查最新 Ubuntu 22.04 镜像 ID"
  type        = string
  default     = "ubuntu_22_04_x64_20G_alibase_20260615.vhd"
}

variable "ecs_system_disk_size" {
  description = "系统盘大小（GB）。只支持扩容，不支持缩小"
  type        = number
  default     = 40
}

variable "ecs_internet_bandwidth_out" {
  description = "ECS 公网出带宽（Mbps）。生产环境后端不应有公网 IP，应走 NAT 网关 + 跳板机"
  type        = number
  default     = 2
}

variable "ecs_password" {
  description = "ECS root 密码（8-30 位，必须同时含大写、小写、数字）"
  type        = string
  sensitive   = true

  validation {
    condition = (
      length(var.ecs_password) >= 8 && length(var.ecs_password) <= 30 &&
      can(regex("[A-Z]", var.ecs_password)) &&
      can(regex("[a-z]", var.ecs_password)) &&
      can(regex("[0-9]", var.ecs_password))
    )
    error_message = "密码必须是 8-30 位，且同时包含大写字母、小写字母和数字。"
  }
}

# ---------- SLB ----------

variable "slb_name" {
  description = "SLB 实例名"
  type        = string
  default     = "ha-slb"
}

variable "slb_spec" {
  description = "SLB 规格"
  type        = string
  default     = "slb.s2.small"
}

variable "slb_backend_weight" {
  description = "后端权重。灰度时把待观察节点调到 0 或小值"
  type        = number
  default     = 100
}

# ---------- RDS ----------

variable "rds_name" {
  description = "RDS 实例名"
  type        = string
  default     = "ha-mysql"
}

variable "rds_instance_class" {
  description = "RDS 规格。如提示规格不可售，用控制台或 DescribeAvailableClasses 查当前可售规格后覆盖"
  type        = string
  default     = "mysql.n2.small.1"
}

variable "rds_instance_storage" {
  description = "RDS 存储大小（GB），必须是 5 的倍数。只支持扩容"
  type        = number
  default     = 20

  validation {
    condition     = var.rds_instance_storage >= 20 && var.rds_instance_storage % 5 == 0
    error_message = "RDS 存储最小 20GB，且必须是 5 的倍数。"
  }
}

variable "rds_storage_type" {
  description = "RDS 存储类型：cloud_essd / cloud_ssd"
  type        = string
  default     = "cloud_essd"
}

variable "rds_db_name" {
  description = "业务数据库名"
  type        = string
  default     = "app_database"
}

variable "rds_account_name" {
  description = "业务数据库账号"
  type        = string
  default     = "app_user"
}

variable "rds_account_password" {
  description = "RDS 账号密码（8-32 位，必须同时含大写、小写、数字）"
  type        = string
  sensitive   = true

  validation {
    condition = (
      length(var.rds_account_password) >= 8 && length(var.rds_account_password) <= 32 &&
      can(regex("[A-Z]", var.rds_account_password)) &&
      can(regex("[a-z]", var.rds_account_password)) &&
      can(regex("[0-9]", var.rds_account_password))
    )
    error_message = "密码必须是 8-32 位，且同时包含大写字母、小写字母和数字。"
  }
}

# ---------- OSS ----------

variable "oss_bucket_name_prefix" {
  description = "OSS Bucket 名前缀（Bucket 名全局唯一，实际名字会拼接随机后缀）"
  type        = string
  default     = "ha-oss-bucket"
}
