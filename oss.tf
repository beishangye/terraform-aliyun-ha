# ==================== 16. 创建 OSS 存储桶 ====================
resource "alicloud_oss_bucket" "bucket" {
  bucket        = "${var.oss_bucket_name_prefix}-${random_integer.suffix.result}"
  acl           = "private"
  storage_class = "Standard"

  tags = {
    Name        = "${var.oss_bucket_name_prefix}-${random_integer.suffix.result}"
    Environment = "dev"
    Project     = "ha-demo"
  }
}

resource "random_integer" "suffix" {
  min = 10000
  max = 99999
}
