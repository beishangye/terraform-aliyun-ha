terraform {
  # 锁死 Terraform CLI 主版本：避免半年后新版行为差异导致 plan 漂移
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    alicloud = {
      source = "aliyun/alicloud"
      # 约束大版本；精确版本由 .terraform.lock.hcl 锁定。
      # 升级 provider 需要显式 `terraform init -upgrade` 并 review plan，
      # 不会因为别人机器上 init 就悄悄变版本。
      version = "~> 1.294"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # ============================================================
  # 远程 State（重要：启用前请先完成下面三步，否则 init 会失败）
  #
  #   1. 创建 OSS Bucket 存放 state（开启版本控制 + 服务端加密）
  #   2. 创建 Tablestore 实例与表，用于 state 锁
  #      —— 注意：锁不在 OSS 上，OSS backend 的锁由 Tablestore 提供
  #   3. 取消下面注释，执行 terraform init -migrate-state
  #
  # 本地 state 是单点：硬盘坏了/换电脑 = Terraform 失忆，
  # 届时只能靠 tag 找回资源再逐个 import。生产必须用远程 state。
  # ============================================================
  #
  # backend "oss" {
  #   bucket           = "your-tfstate-bucket"
  #   prefix           = "terraform-aliyun-ha"
  #   region           = "cn-hangzhou"
  #   encrypt          = true
  #   tablestore_table = "tfstate-lock"
  # }
}
