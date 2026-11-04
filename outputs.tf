# ============================================================
# 输出
#
# 说明：这里不输出任何密码类信息。
# 如果需要把密码交给下游（如 Ansible），用 data 源从 KMS / 凭据管家读取，
# 不要通过 terraform output 传递 —— output 会明文落在 state 里。
# ============================================================

output "slb_public_ip" {
  description = "SLB 公网 IP，浏览器访问 http://<这个IP>"
  value       = alicloud_slb_load_balancer.slb.address
}

output "ecs_web01_private_ip" {
  description = "web01 内网 IP"
  value       = alicloud_instance.ecs_web01.private_ip
}

output "ecs_web02_private_ip" {
  description = "web02 内网 IP"
  value       = alicloud_instance.ecs_web02.private_ip
}

output "ecs_web01_public_ip" {
  description = "web01 公网 IP（调试用；生产环境后端不应有公网 IP）"
  value       = alicloud_instance.ecs_web01.public_ip
}

output "ecs_web02_public_ip" {
  description = "web02 公网 IP（调试用；生产环境后端不应有公网 IP）"
  value       = alicloud_instance.ecs_web02.public_ip
}

output "ssh_web01_command" {
  description = "登录 web01 的命令"
  value       = "ssh root@${alicloud_instance.ecs_web01.public_ip}"
}

output "ssh_web02_command" {
  description = "登录 web02 的命令"
  value       = "ssh root@${alicloud_instance.ecs_web02.public_ip}"
}

output "rds_connection_string" {
  description = "RDS 内网连接地址（同 VPC 内 ECS 使用）"
  value       = alicloud_db_instance.rds.connection_string
}

output "rds_port" {
  description = "RDS 端口"
  value       = alicloud_db_instance.rds.port
}

output "rds_zone" {
  description = "RDS 所在可用区（显式指定，不再自动选择）"
  value       = alicloud_db_instance.rds.zone_id
}

output "rds_database_name" {
  description = "业务数据库名"
  value       = alicloud_db_database.db.data_base_name
}

output "rds_account_name" {
  description = "业务数据库账号"
  value       = alicloud_db_account.account.account_name
}

output "rds_instance_id" {
  description = "RDS 实例 ID"
  value       = alicloud_db_instance.rds.id
}

output "oss_bucket_name" {
  description = "OSS Bucket 名称"
  value       = alicloud_oss_bucket.bucket.bucket
}

output "oss_intranet_endpoint" {
  description = "OSS 内网 Endpoint（同地域 ECS 访问免流量费）"
  value       = alicloud_oss_bucket.bucket.intranet_endpoint
}
