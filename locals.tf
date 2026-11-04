# ============================================================
# 公共局部值
# ============================================================

locals {
  # 统一标签：成本分摊 + 批量查找 + 自动化清理的筛选条件
  # 注意：打了标签不用，等于没打。至少要在「成本分析」里按 Project 分过一次组
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  # Web 层内网网段：用于收窄 RDS 白名单，只放行真正需要连库的机器
  web_subnet_cidrs = [var.vswitch_web1_cidr, var.vswitch_web2_cidr]
}
