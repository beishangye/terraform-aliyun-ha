# ==================== 12. 创建 RDS MySQL 实例 ====================
resource "alicloud_db_instance" "rds" {
  engine               = "MySQL"
  engine_version       = "8.0"
  instance_type        = data.alicloud_db_instance_classes.rds.instance_classes[0].instance_class
  instance_storage     = data.alicloud_db_instance_classes.rds.instance_classes[0].storage_range.min
  instance_charge_type = "Postpaid"
  instance_name        = var.rds_name
  vswitch_id           = alicloud_vswitch.vswitch_rds.id
  security_ips         = [var.vpc_cidr]
  zone_id              = data.alicloud_db_zones.rds.zones[0].id
  category             = "HighAvailability"
  db_instance_storage_type = "cloud_ssd"

  tags = {
    Name        = var.rds_name
    Environment = "dev"
    Project     = "ha-demo"
  }
}

# ==================== 13. 创建 RDS 数据库 ====================
resource "alicloud_db_database" "db" {
  instance_id   = alicloud_db_instance.rds.id
  name          = var.rds_db_name
  character_set = "utf8mb4"
}

# ==================== 14. 创建 RDS 数据库账号 ====================
resource "alicloud_db_account" "account" {
  db_instance_id   = alicloud_db_instance.rds.id
  account_name     = var.rds_account_name
  account_password = var.rds_account_password
  account_type     = "Normal"
}

# ==================== 15. 授予账号数据库读写权限 ====================
resource "alicloud_db_account_privilege" "privilege" {
  instance_id  = alicloud_db_instance.rds.id
  account_name = alicloud_db_account.account.account_name
  privilege    = "ReadWrite"
  db_names     = [alicloud_db_database.db.name]
}