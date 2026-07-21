# ==================== 数据源：查询有库存的可用区与规格 ====================
data "alicloud_db_zones" "rds" {
  engine               = "MySQL"
  engine_version       = "8.0"
  instance_charge_type = "PostPaid"
  category             = "HighAvailability"
  db_instance_storage_type = "cloud_ssd"
  multi_zone           = false
}

data "alicloud_db_instance_classes" "rds" {
  zone_id              = data.alicloud_db_zones.rds.zones[0].id
  engine               = "MySQL"
  engine_version       = "8.0"
  category             = "HighAvailability"
  db_instance_storage_type = "cloud_ssd"
  instance_charge_type = "PostPaid"
}

# ==================== 1. 创建 VPC ====================
resource "alicloud_vpc" "vpc" {
  vpc_name   = var.vpc_name
  cidr_block = var.vpc_cidr
  tags = {
    Name = var.vpc_name
  }
}

# ==================== 2. 创建 Web 交换机（可用区 h） ====================
resource "alicloud_vswitch" "vswitch_web1" {
  vpc_id       = alicloud_vpc.vpc.id
  cidr_block   = var.vswitch_web1_cidr
  zone_id      = var.az_web1
  vswitch_name = "vs-web1-h"
  tags = {
    Name = "vs-web1-h"
  }
}

# ==================== 3. 创建 Web 交换机（可用区 i） ====================
resource "alicloud_vswitch" "vswitch_web2" {
  vpc_id       = alicloud_vpc.vpc.id
  cidr_block   = var.vswitch_web2_cidr
  zone_id      = var.az_web2
  vswitch_name = "vs-web2-i"
  tags = {
    Name = "vs-web2-i"
  }
}

# ==================== 4. 创建 RDS 专用交换机（可用区由 data 决定） ====================
resource "alicloud_vswitch" "vswitch_rds" {
  vpc_id       = alicloud_vpc.vpc.id
  cidr_block   = var.vswitch_rds_cidr
  zone_id      = data.alicloud_db_zones.rds.zones[0].id
  vswitch_name = "vs-rds-${data.alicloud_db_zones.rds.zones[0].id}"
  tags = {
    Name = "vs-rds"
  }
}

# ==================== 5. 创建安全组 ====================
resource "alicloud_security_group" "sg" {
  name        = var.sg_name
  description = "Security group for HA web servers and RDS"
  vpc_id      = alicloud_vpc.vpc.id
  tags = {
    Name = var.sg_name
  }
}

# ==================== 6. 安全组规则 ====================
resource "alicloud_security_group_rule" "allow_http" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "80/80"
  priority          = 1
  security_group_id = alicloud_security_group.sg.id
  cidr_ip           = "0.0.0.0/0"
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
}

resource "alicloud_security_group_rule" "allow_mysql" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "3306/3306"
  priority          = 2
  security_group_id = alicloud_security_group.sg.id
  cidr_ip           = var.vpc_cidr
}

# ==================== 7. 创建 Web 实例 01（可用区 h） ====================
resource "alicloud_instance" "ecs_web01" {
  availability_zone          = var.az_web1
  vswitch_id                 = alicloud_vswitch.vswitch_web1.id
  security_groups            = [alicloud_security_group.sg.id]
  image_id                   = var.ecs_image
  instance_type              = var.ecs_type
  instance_name              = "${var.ecs_name}-01"
  internet_max_bandwidth_out = 2
  internet_charge_type       = "PayByTraffic"
  instance_charge_type       = "PostPaid"
  system_disk_category       = "cloud_auto"
  system_disk_size           = 40
  password                   = var.ecs_password

  tags = {
    Name        = "${var.ecs_name}-01"
    Environment = "dev"
    Project     = "ha-demo"
  }

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y nginx
    systemctl start nginx
    systemctl enable nginx
    echo "<h1>Hello from web01 (az-h) $(hostname)</h1>" > /var/www/html/index.html
  EOF
}

# ==================== 8. 创建 Web 实例 02（可用区 i） ====================
resource "alicloud_instance" "ecs_web02" {
  availability_zone          = var.az_web2
  vswitch_id                 = alicloud_vswitch.vswitch_web2.id
  security_groups            = [alicloud_security_group.sg.id]
  image_id                   = var.ecs_image
  instance_type              = var.ecs_type
  instance_name              = "${var.ecs_name}-02"
  internet_max_bandwidth_out = 2
  internet_charge_type       = "PayByTraffic"
  instance_charge_type       = "PostPaid"
  system_disk_category       = "cloud_auto"
  system_disk_size           = 40
  password                   = var.ecs_password

  tags = {
    Name        = "${var.ecs_name}-02"
    Environment = "dev"
    Project     = "ha-demo"
  }

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y nginx
    systemctl start nginx
    systemctl enable nginx
    echo "<h1>Hello from web02 (az-i) $(hostname)</h1>" > /var/www/html/index.html
  EOF
}

# ==================== 9. 创建公网 SLB 实例（部署在可用区 h） ====================
resource "alicloud_slb_load_balancer" "slb" {
  load_balancer_name   = var.slb_name
  load_balancer_spec   = "slb.s2.small"
  internet_charge_type = "PayByTraffic"
  address_type         = "internet"
  vswitch_id           = alicloud_vswitch.vswitch_web1.id
  tags = {
    Name        = var.slb_name
    Environment = "dev"
    Project     = "ha-demo"
  }
}

# ==================== 10. 创建 HTTP 监听 ====================
resource "alicloud_slb_listener" "http" {
  load_balancer_id      = alicloud_slb_load_balancer.slb.id
  backend_port          = 80
  frontend_port         = 80
  protocol              = "http"
  bandwidth             = -1
  health_check          = "on"
  health_check_uri      = "/"
  health_check_method   = "get"
  health_check_timeout  = 5
  health_check_interval = 2
  unhealthy_threshold   = 3
  healthy_threshold     = 2
}

# ==================== 11. 将 Web 实例添加到 SLB 后端 ====================
resource "alicloud_slb_attachment" "slb_attach_01" {
  load_balancer_id = alicloud_slb_load_balancer.slb.id
  instance_ids     = [alicloud_instance.ecs_web01.id]
  weight           = 100
}

resource "alicloud_slb_attachment" "slb_attach_02" {
  load_balancer_id = alicloud_slb_load_balancer.slb.id
  instance_ids     = [alicloud_instance.ecs_web02.id]
  weight           = 100
}