# ============================================================
# RDS MySQL
#
# 本次修复记录：
#   1. 去掉了两个 data 源（alicloud_db_zones / alicloud_db_instance_classes）。
#      原写法 zone_id 取 zones[0]、规格取 instance_classes[0]、
#      存储取 storage_range.min —— 三个都是"当天云上碰巧有什么"。
#      库存一变（某可用区售罄 / 上架了新规格），plan 就会显示
#      RDS 需要 replace，而 RDS 的 replace 等于删库重建，不做任何数据迁移。
#      现在三个关键参数全部显式化，plan 的行为变成可预测的。
#   2. security_ips 从整个 VPC（172.16.0.0/16）收窄到两个 Web 子网。
#      数据库白名单应该只放行"确实需要连库的机器"，不是整个网段。
#   3. category = HighAvailability + 单可用区 = 同机房主备热备。
#      它防单机故障（宕机、进程崩溃、磁盘损坏），不防可用区级故障。
#      需要机房级容灾时改用集群版/三节点企业版（multi_zone = true）。
# ============================================================

# ==================== 12. RDS 实例 ====================
resource "alicloud_db_instance" "rds" {
  engine               = "MySQL"
  engine_version       = "8.0"
  category             = "HighAvailability"
  instance_charge_type = "Postpaid"
  instance_name        = var.rds_name

  # 以下三项是 ForceNew，一旦变化 = 删库重建。所以必须显式、稳定。
  zone_id          = var.az_rds
  instance_type    = var.rds_instance_class
  instance_storage = var.rds_instance_storage

  db_instance_storage_type = var.rds_storage_type
  vswitch_id               = alicloud_vswitch.vswitch_rds.id

  # 白名单：只放行 Web 层两个子网，不使用整个 VPC 网段
  security_ips = local.web_subnet_cidrs

  # 连接日志 / 慢日志（对应 Checkov CKV_ALI_35 / 36 / 37）
  # 排障价值：出问题时能回答"谁在什么时候连过、哪条 SQL 慢"
  # 代价：log_duration 会记录每条语句的耗时，日志量偏大；
  #      生产上通常改为只开 slow_query_log + long_query_time
  parameters {
    name  = "log_connections"
    value = "ON"
  }

  parameters {
    name  = "log_disconnections"
    value = "ON"
  }

  parameters {
    name  = "log_duration"
    value = "ON"
  }

  tags = merge(local.common_tags, { Name = var.rds_name })
}

# ==================== 13. 业务数据库 ====================
# provider 1.266.0 起 name 字段弃用，改用 data_base_name
resource "alicloud_db_database" "db" {
  instance_id    = alicloud_db_instance.rds.id
  data_base_name = var.rds_db_name
  character_set  = "utf8mb4"
}

# ==================== 14. 业务账号 ====================
resource "alicloud_db_account" "account" {
  db_instance_id   = alicloud_db_instance.rds.id
  account_name     = var.rds_account_name
  account_password = var.rds_account_password
  account_type     = "Normal"
}

# ==================== 15. 授权（最小权限：只给业务库读写） ====================
resource "alicloud_db_account_privilege" "privilege" {
  instance_id  = alicloud_db_instance.rds.id
  account_name = alicloud_db_account.account.account_name
  privilege    = "ReadWrite"
  db_names     = [alicloud_db_database.db.data_base_name]
}
