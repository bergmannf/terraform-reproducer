resource "openstack_networking_network_v2" "network" {
  name           = var.internal_net
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "subnet" {
  name       = var.internal_subnet
  network_id = openstack_networking_network_v2.network.id
  cidr       = "172.28.0.0/24"
  ip_version = 4
}

data "openstack_networking_network_v2" "external_network" {
  name = var.external_net
}

// This is needed to make the external net reachable from the subnet
resource "openstack_networking_router_v2" "router" {
  name                = "${var.internal_net}-router"
  external_network_id = data.openstack_networking_network_v2.external_network.id
}

// This is needed to make the external net reachable from the subnet
resource "openstack_networking_router_interface_v2" "router_interface" {
  router_id = openstack_networking_router_v2.router.id
  subnet_id = openstack_networking_subnet_v2.subnet.id
}

// Setup a security group for ssh access
resource "openstack_networking_secgroup_v2" "secgroup" {
  name        = "terraform-test-secgroup"
  description = "Common security group for CaaSP nodes"
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.secgroup.id
}

data "template_file" "machine_cloud_init" {
  template = file("cloud-init/init.tpl")

  vars = {
    authorized_keys = join("\n", formatlist("  - %s", var.authorized_keys))
    username        = var.username
  }
}

resource "openstack_compute_instance_v2" "machine" {
  count      = var.machines
  name       = "terraform-test-test-machine-${count.index}"
  image_name = var.image_name
  key_pair   = var.key_pair

  depends_on = [
    openstack_networking_network_v2.network,
    openstack_networking_subnet_v2.subnet,
  ]

  flavor_name = var.machine_size

  network {
    name = var.internal_net
  }

  security_groups = [
    openstack_networking_secgroup_v2.secgroup.name
  ]

  user_data = data.template_file.machine_cloud_init.rendered
}

resource "openstack_networking_floatingip_v2" "worker_ext" {
  count = var.machines
  pool  = var.external_net
}

resource "openstack_compute_floatingip_associate_v2" "worker_ext_ip" {
  count = var.machines
  floating_ip = element(
    openstack_networking_floatingip_v2.worker_ext[*].address,
    count.index,
  )
  instance_id = element(openstack_compute_instance_v2.machine[*].id, count.index)
}

resource "null_resource" "machine_wait_cloudinit" {
  depends_on = [openstack_compute_instance_v2.machine]
  count      = var.machines

  connection {
    host = element(
      openstack_compute_floatingip_associate_v2.worker_ext_ip[*].floating_ip,
      count.index
    )
    user = var.username
    type = "ssh"
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait > /dev/null"
    ]
  }
}
