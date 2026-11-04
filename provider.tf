# ============================================================
# 阿里云 Provider
#
# 注意事项：
#   1. 凭证不要写在这里，也不要写进 tfvars。
#      用环境变量 ALICLOUD_ACCESS_KEY / ALICLOUD_SECRET_KEY，
#      或 `aliyun configure` 生成的本地凭证文件。
#      生产环境请改用 RAM 角色 + STS 临时凭证。
#   2. 同一个 provider 块只能声明一次 —— 原 variables.tf 里重复声明了，
#      已删除（Terraform 不报错，但属于配置噪音）。
# ============================================================
provider "alicloud" {
  region = var.region
}
