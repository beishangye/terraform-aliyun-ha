# ============================================================
# VPC / 交换机 / 安全组 / ECS / SLB
#
# 本次修复记录：
#   1. 删除了 RDS 相关的两个 data 源（zones / instance_classes）。
#      data 源每次 plan 都实时求值，库存变化会让 zone_id 漂移，
#      而 RDS 的 zone_id 是 ForceNew —— 会静默触发"删库重建"。
#      改为显式变量（见 variables.tf 的 az_rds）。
#   2. 删除了 3306 安全组规则（原 allow_mysql）。
#      Web 机器上没有任何进程监听 3306，这条规则只增加攻击面、
#      不提供任何能力。RDS 的访问控制由 security_ips 负责。
#   3. user_data 增加 set -euo pipefail + DEBIAN_FRONTEND=noninteractive，
#      并新增 /healthz 端点供 SLB 探测（原来探的是 "/"，见第 5 条）。
#   4. 健康检查参数修正：timeout 必须小于 interval。
#      原配置 timeout=5 > interval=2，探测会重叠，判定窗口不可预测
#      （实际摘除时间在 6~20 秒之间浮动，而不是 3×2=6 秒）。
#   5. health_check_uri 从 "/" 改为 "/healthz"。
#      "/" 是业务页面，返回码会随业务变（301/403 都会让 SLB 误判）。
# ============================================================

# ==================== 1. VPC ====================
resource "alicloud_vpc" "vpc" {
  vpc_name   = var.vpc_name
  cidr_block = var.vpc_cidr

  tags = merge(local.common_tags, { Name = var.vpc_name })
}

# ==================== 2. Web 交换机（可用区 1） ====================
resource "alicloud_vswitch" "vswitch_web1" {
  vpc_id       = alicloud_vpc.vpc.id
  cidr_block   = var.vswitch_web1_cidr
  zone_id      = var.az_web1
  vswitch_name = "vs-web1-${var.az_web1}"

  tags = merge(local.common_tags, { Name = "vs-web1-${var.az_web1}" })
}

# ==================== 3. Web 交换机（可用区 2） ====================
resource "alicloud_vswitch" "vswitch_web2" {
  vpc_id       = alicloud_vpc.vpc.id
  cidr_block   = var.vswitch_web2_cidr
  zone_id      = var.az_web2
  vswitch_name = "vs-web2-${var.az_web2}"

  tags = merge(local.common_tags, { Name = "vs-web2-${var.az_web2}" })
}

# ==================== 4. RDS 专用交换机（可用区显式指定） ====================
resource "alicloud_vswitch" "vswitch_rds" {
  vpc_id       = alicloud_vpc.vpc.id
  cidr_block   = var.vswitch_rds_cidr
  zone_id      = var.az_rds
  vswitch_name = "vs-rds-${var.az_rds}"

  tags = merge(local.common_tags, { Name = "vs-rds-${var.az_rds}" })
}

# ==================== 5. 安全组 ====================
resource "alicloud_security_group" "sg" {
  security_group_name = var.sg_name
  description         = "HA web tier: 80 from SLB clients, 22 from operator IP only"
  vpc_id              = alicloud_vpc.vpc.id

  tags = merge(local.common_tags, { Name = var.sg_name })
}

# ==================== 6. 安全组规则 ====================
#
# nic_type 说明（面试常问）：
#   VPC 类型的 ECS 只有一块弹性网卡（ENI），公网 IP 是 NAT 映射在这块网卡上的。
#   所以无论是公网流量还是内网流量，都经过同一块 ENI，规则写 intranet 即可。
#   internet 是经典网络时代的遗留概念（那时代公网/内网是两块独立网卡）。

resource "alicloud_security_group_rule" "allow_http" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "80/80"
  priority          = 1
  security_group_id = alicloud_security_group.sg.id
  cidr_ip           = "0.0.0.0/0"

  # 说明：后端只接受 SLB 转发过来的流量，理论上可以收窄到 SLB 的地址段。
  # 但 SLB 后端地址段随实例变化，这里放开 80 是最简做法；
  # 生产环境应改为「安全组引用」或直接让 ECS 不分配公网 IP。
}

resource "alicloud_security_group_rule" "allow_ssh" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "22/22"
  priority          = 1
  security_group_id = alicloud_security_group.sg.id
  cidr_ip           = var.my_ip

  # my_ip 没有默认值，且校验会拒绝 0.0.0.0/0 —— 见 variables.tf
}

# ==================== 7. Web 实例 01 ====================
resource "alicloud_instance" "ecs_web01" {
  availability_zone          = var.az_web1
  vswitch_id                 = alicloud_vswitch.vswitch_web1.id
  security_groups            = [alicloud_security_group.sg.id]
  image_id                   = var.ecs_image
  instance_type              = var.ecs_type
  instance_name              = "${var.ecs_name}-01"
  internet_max_bandwidth_out = var.ecs_internet_bandwidth_out
  internet_charge_type       = "PayByTraffic"
  instance_charge_type       = "PostPaid"
  system_disk_category       = "cloud_auto"
  system_disk_size           = var.ecs_system_disk_size
  password                   = var.ecs_password

  tags = merge(local.common_tags, { Name = "${var.ecs_name}-01" })

  # 注意：Terraform 不会等 user_data 执行完 —— apply 成功只代表 API 调用成功。
  # 因此脚本末尾加了自检循环；但即便它失败，apply 也不会报错。
  # 部署后请跑 scripts/verify-deployment.sh 做外部验收。
  #
  # 另一个坑：user_data 在 alicloud provider 里是 ForceNew。
  # 改这里的任何一行 → plan 会显示 replace → 两台 ECS 被删掉重建。
  # 所以「改配置」不应该走 user_data，应该交给配置管理工具（Ansible）或自定义镜像。
  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive

    apt-get update -y
    apt-get install -y --no-install-recommends nginx curl

    systemctl enable --now nginx

    # SLB 健康检查专用端点（liveness：只证明进程活着）
    # 真正的 readiness（依赖可用）需要应用自己实现，见 README「已知局限」
    echo "ok" > /var/www/html/healthz

    echo "<h1>Hello from ${var.ecs_name}-01 (${var.az_web1})</h1><p>host: $(hostname)</p>" > /var/www/html/index.html

    for i in $(seq 1 30); do
      if curl -sf -o /dev/null http://127.0.0.1/healthz; then
        echo "nginx ready after $${i} tries"
        exit 0
      fi
      sleep 2
    done

    echo "nginx 未在 60 秒内就绪" >&2
    exit 1
  EOF
}

# ==================== 8. Web 实例 02 ====================
resource "alicloud_instance" "ecs_web02" {
  availability_zone          = var.az_web2
  vswitch_id                 = alicloud_vswitch.vswitch_web2.id
  security_groups            = [alicloud_security_group.sg.id]
  image_id                   = var.ecs_image
  instance_type              = var.ecs_type
  instance_name              = "${var.ecs_name}-02"
  internet_max_bandwidth_out = var.ecs_internet_bandwidth_out
  internet_charge_type       = "PayByTraffic"
  instance_charge_type       = "PostPaid"
  system_disk_category       = "cloud_auto"
  system_disk_size           = var.ecs_system_disk_size
  password                   = var.ecs_password

  tags = merge(local.common_tags, { Name = "${var.ecs_name}-02" })

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive

    apt-get update -y
    apt-get install -y --no-install-recommends nginx curl

    systemctl enable --now nginx

    echo "ok" > /var/www/html/healthz

    echo "<h1>Hello from ${var.ecs_name}-02 (${var.az_web2})</h1><p>host: $(hostname)</p>" > /var/www/html/index.html

    for i in $(seq 1 30); do
      if curl -sf -o /dev/null http://127.0.0.1/healthz; then
        echo "nginx ready after $${i} tries"
        exit 0
      fi
      sleep 2
    done

    echo "nginx 未在 60 秒内就绪" >&2
    exit 1
  EOF
}

# ==================== 9. 公网 SLB ====================
resource "alicloud_slb_load_balancer" "slb" {
  load_balancer_name   = var.slb_name
  load_balancer_spec   = var.slb_spec
  internet_charge_type = "PayByTraffic"
  address_type         = "internet"
  vswitch_id           = alicloud_vswitch.vswitch_web1.id

  tags = merge(local.common_tags, { Name = var.slb_name })

  # 说明：CLB 是地域级产品、多可用区集群部署，单可用区故障不影响公网入口。
  # 这里只给了 vswitch_id，等于让私网侧默认落在 az_web1；
  # 需要主动设计多可用区容灾时，应显式配置 master_zone_id / slave_zone_id。
}

# ==================== 10. HTTP 监听 ====================
resource "alicloud_slb_listener" "http" {
  load_balancer_id = alicloud_slb_load_balancer.slb.id
  backend_port     = 80
  frontend_port    = 80
  protocol         = "http"
  bandwidth        = -1

  health_check           = "on"
  health_check_uri       = "/healthz"
  health_check_method    = "get"
  health_check_http_code = "http_2xx"
  # 关键：timeout 必须小于 interval，否则单次探测还没收敛就发起下一次，
  # 判定窗口会变得不可预测（原配置 5 > 2）
  health_check_timeout  = 3
  health_check_interval = 5
  unhealthy_threshold   = 3
  healthy_threshold     = 3
}

# ==================== 11. 挂载后端 ====================
# 注意：alicloud_slb_attachment 自 provider 1.153.0 起弃用，
# 改用 alicloud_slb_backend_server（一次声明整个后端列表，更符合 API 语义）
resource "alicloud_slb_backend_server" "web" {
  load_balancer_id = alicloud_slb_load_balancer.slb.id

  backend_servers {
    server_id = alicloud_instance.ecs_web01.id
    weight    = var.slb_backend_weight
  }

  backend_servers {
    server_id = alicloud_instance.ecs_web02.id
    weight    = var.slb_backend_weight
  }
}
