provider "alicloud" {
  access_key = var.access_key
  secret_key = var.secret_key

  # If not set, cn-beijing will be used.
  region = "me-central-1" #var.region
}

# Create a new ECS instance for VPC
resource "alicloud_vpc" "vpc" {
  vpc_name   = "VPC"
  cidr_block = "10.0.0.0/8"
}

data "alicloud_zones" "default" {
  available_disk_category     = "cloud_efficiency"
  available_resource_creation = "VSwitch"
}

resource "alicloud_vswitch" "public" {
  vpc_id       = alicloud_vpc.vpc.id
  cidr_block   = "10.0.1.0/24"
  zone_id      = data.alicloud_zones.default.zones.0.id
  vswitch_name = "public-vswitch"
}

resource "alicloud_vswitch" "private" {
  vpc_id       = alicloud_vpc.vpc.id
  cidr_block   = "10.0.2.0/24"
  zone_id      = data.alicloud_zones.default.zones.0.id
  vswitch_name = "private-vswitch"
}

resource "alicloud_security_group" "web" {
  name        = "web-sg"
  description = "this is web securety group for web and http"
  vpc_id      = alicloud_vpc.vpc.id
}

resource "alicloud_security_group_rule" "allow_ssh_to_web" {
  type              = "ingress"
  ip_protocol       = "tcp"
  policy            = "accept"
  port_range        = "22/22"
  security_group_id = alicloud_security_group.web.id
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_security_group_rule" "allow_http_to_web" {
  type              = "ingress"
  ip_protocol       = "tcp"
  policy            = "accept"
  port_range        = "80/80"
  security_group_id = alicloud_security_group.web.id
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_key_pair" "publickey" {
  key_pair_name = "ssh-key"
  key_file      = "ssh-key.pem"
}

resource "alicloud_instance" "web" {

  availability_zone = data.alicloud_zones.default.zones.0.id
  security_groups   = [alicloud_security_group.web.id]

  instance_type              = "ecs.g6.large"
  system_disk_category       = "cloud_essd"
  image_id                   = var.image_id
  instance_name              = "bastion"
  internet_charge_type       = "PayByTraffic"
  instance_charge_type       = "PostPaid"
  vswitch_id                 = alicloud_vswitch.public.id
  internet_max_bandwidth_out = 100
  key_name                   = alicloud_key_pair.publickey.key_pair_name

  data_disks {
    name     = "public-disk"
    size     = 40
    category = "cloud_essd"

  }

  user_data = base64encode(file("cloud-init.yml"))
}

output "web_public_ip" {
  value = alicloud_instance.web.public_ip
}
