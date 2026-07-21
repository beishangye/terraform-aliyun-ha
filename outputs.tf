# ==================== 17. 输出信息 ====================
output "slb_public_ip" {
  description = "SLB 公网 IP 地址"
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
  description = "web01 公网 IP（调试用）"
  value       = alicloud_instance.ecs_web01.public_ip
}

output "ecs_web02_public_ip" {
  description = "web02 公网 IP（调试用）"
  value       = alicloud_instance.ecs_web02.public_ip
}

output "ssh_web01_command" {
  description = "SSH 登录 web01 命令"
  value       = "ssh root@${alicloud_instance.ecs_web01.public_ip}"
}

output "ssh_web02_command" {
  description = "SSH 登录 web02 命令"
  value       = "ssh root@${alicloud_instance.ecs_web02.public_ip}"
}

output "rds_connection_string" {
  description = "RDS MySQL 内网连接地址"
  value       = alicloud_db_instance.rds.connection_string
}

output "rds_port" {
  description = "RDS MySQL 端口"
  value       = alicloud_db_instance.rds.port
}

output "rds_database_name" {
  description = "RDS 数据库名称"
  value       = alicloud_db_database.db.name
}

output "rds_account_name" {
  description = "RDS 数据库账号"
  value       = alicloud_db_account.account.account_name
}

output "rds_instance_id" {
  description = "RDS 实例 ID"
  value       = alicloud_db_instance.rds.id
}

output "oss_bucket_name" {
  description = "OSS 存储桶名称"
  value       = alicloud_oss_bucket.bucket.bucket
}

output "oss_intranet_endpoint" {
  description = "OSS 内网访问 Endpoint（同区域 ECS 免流量）"
  value       = alicloud_oss_bucket.bucket.intranet_endpoint
}

output "selected_zone" {
  description = "RDS 自动选择的可用区"
  value       = data.alicloud_db_zones.rds.zones[0].id
}

output "selected_instance_class" {
  description = "RDS 自动选择的实例规格"
  value       = data.alicloud_db_instance_classes.rds.instance_classes[0].instance_class
}