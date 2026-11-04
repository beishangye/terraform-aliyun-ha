# ============================================================
# OSS 对象存储
#
# 本次修复记录：
#   1. random_integer 增加 keepers 参数。
#      原写法没有 keepers，state 丢失或 provider 重装后可能算出新的随机数，
#      导致「新建一个空 Bucket，旧数据看起来消失了」。
#      keepers 让随机值只随 prefix 变化，apply 之间保持稳定。
#   2. 增加服务端加密（AES256）。
#   3. 增加 Bucket Policy：拒绝非 HTTPS 访问。
#      private ACL 只解决「谁能访问」，不解决「怎么访问」——
#      明文 HTTP 上传的对象，传输过程仍然是裸的。
# ============================================================

# ==================== 16. Bucket ====================
# 注意：alicloud provider 1.220.0 起，bucket 的 acl 字段已弃用，
# 私有读写改用独立的 alicloud_oss_bucket_acl 资源声明（见第 17 节）
resource "alicloud_oss_bucket" "bucket" {
  bucket        = "${var.oss_bucket_name_prefix}-${random_integer.suffix.result}"
  storage_class = "Standard"

  tags = merge(local.common_tags, {
    Name = "${var.oss_bucket_name_prefix}-${random_integer.suffix.result}"
  })
}

# 随机后缀：keepers 保证它不会在 apply 之间跳变
resource "random_integer" "suffix" {
  min = 10000
  max = 99999

  keepers = {
    prefix = var.oss_bucket_name_prefix
  }
}

# ==================== 17. 访问控制：私有读写 ====================
resource "alicloud_oss_bucket_acl" "bucket" {
  bucket = alicloud_oss_bucket.bucket.bucket
  acl    = "private"
}

# ==================== 18. 版本控制 ====================
# 对应 Checkov CKV_ALI_10。
# 开了版本控制之后，误删/误覆盖的对象可以恢复 —— 这是对象存储最便宜的"后悔药"。
# 代价：每个旧版本都算存储费，配合生命周期规则清理历史版本。
resource "alicloud_oss_bucket_versioning" "bucket" {
  bucket = alicloud_oss_bucket.bucket.bucket
  status = "Enabled"
}

# ==================== 19. 服务端加密 ====================
resource "alicloud_oss_bucket_server_side_encryption" "sse" {
  bucket        = alicloud_oss_bucket.bucket.bucket
  sse_algorithm = "AES256"
}

# ==================== 20. 强制 HTTPS ====================
resource "alicloud_oss_bucket_policy" "https_only" {
  bucket = alicloud_oss_bucket.bucket.bucket

  policy = jsonencode({
    Version = "1"
    Statement = [
      {
        Effect    = "Deny"
        Action    = ["oss:*"]
        Principal = ["*"]
        Resource = [
          "acs:oss:*:*:${alicloud_oss_bucket.bucket.bucket}",
          "acs:oss:*:*:${alicloud_oss_bucket.bucket.bucket}/*",
        ]
        Condition = {
          Bool = {
            "acs:SecureTransport" = ["false"]
          }
        }
      }
    ]
  })
}
