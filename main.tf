# Configure the Oracle Cloud Infrastructure provider with an API Key

variable "tenancy_ocid" {
  sensitive = true
}

variable "user_ocid" {
  sensitive = true
}

variable "fingerprint" {
  sensitive = true
}

variable "region" {
  sensitive = true
}

variable "private_key" {
  sensitive = true
}

variable "shape" {
  default = "VM.Standard.E2.1.Micro"
}

terraform {
  backend "remote" {
    organization = "chrisns"
    workspaces {
      name = "bedrockconnect_oci"
    }
  }
}

provider "oci" {
  tenancy_ocid = var.tenancy_ocid
  user_ocid    = var.user_ocid
  fingerprint  = var.fingerprint
  private_key  = var.private_key
  region       = var.region
}

resource "oci_identity_compartment" "bedrockconnect" {
  compartment_id = var.tenancy_ocid
  description    = "bedrockconnect"
  name           = "bedrockconnect"
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = oci_identity_compartment.bedrockconnect.id
}

resource "oci_core_instance" "bedrockconnect" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[2].name
  compartment_id      = oci_identity_compartment.bedrockconnect.id
  shape               = var.shape
  source_details {
    source_id   = data.oci_core_images.latest_image.images[0].id
    source_type = "image"
  }
  create_vnic_details {
    subnet_id        = oci_core_subnet.bedrockconnect.id
    assign_public_ip = false
    hostname_label   = "bedrockconnect"
  }

  metadata = {
    user_data = base64encode(join("\n", ["#cloud-config", local.cloudinit]))
  }
}

resource "oci_core_vcn" "bedrockconnect" {
  cidr_block     = "10.1.0.0/16"
  compartment_id = oci_identity_compartment.bedrockconnect.id
  display_name   = "bedrockconnect"
  dns_label      = "bedrockconnect"
}

resource "oci_core_internet_gateway" "bedrockconnect" {
  compartment_id = oci_identity_compartment.bedrockconnect.id
  display_name   = "bedrockconnect Gateway"
  vcn_id         = oci_core_vcn.bedrockconnect.id
}

resource "oci_core_default_route_table" "bedrockconnect" {
  manage_default_resource_id = oci_core_vcn.bedrockconnect.default_route_table_id
  display_name               = "DefaultRouteTable"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.bedrockconnect.id
  }
}

resource "oci_core_subnet" "bedrockconnect" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[2].name
  cidr_block          = "10.1.20.0/24"
  dns_label           = "bedrockconnect"
  security_list_ids   = [oci_core_security_list.bedrockconnect.id]
  compartment_id      = oci_identity_compartment.bedrockconnect.id
  vcn_id              = oci_core_vcn.bedrockconnect.id
  route_table_id      = oci_core_vcn.bedrockconnect.default_route_table_id
  dhcp_options_id     = oci_core_vcn.bedrockconnect.default_dhcp_options_id
}

resource "oci_core_public_ip" "bedrockconnect_reserved_ip" {
  compartment_id = oci_identity_compartment.bedrockconnect.id
  lifetime       = "RESERVED"
  private_ip_id  = data.oci_core_private_ips.bedrockconnect_private_ip.private_ips[0].id
}
output "public_ip" {
  value = oci_core_public_ip.bedrockconnect_reserved_ip.ip_address
}
data "oci_core_private_ips" "bedrockconnect_private_ip" {
  ip_address = oci_core_instance.bedrockconnect.private_ip
  subnet_id  = oci_core_subnet.bedrockconnect.id
}

resource "oci_core_security_list" "bedrockconnect" {
  compartment_id = oci_identity_compartment.bedrockconnect.id
  vcn_id         = oci_core_vcn.bedrockconnect.id

  egress_security_rules {
    protocol    = "6"
    destination = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }
  egress_security_rules {
    protocol    = "6"
    destination = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }

  // ingress_security_rules {
  //   description = "ssh"
  //   protocol    = "6"
  //   source      = "0.0.0.0/0"

  //   tcp_options {
  //     max = "22"
  //     min = "22"
  //   }
  // }

  ingress_security_rules {
    description = "minecraft list server"
    protocol    = "6"
    source      = "0.0.0.0/0"

    tcp_options {
      max = "19132"
      min = "19132"
    }
  }
  ingress_security_rules {
    description = "DNS"
    protocol    = "17"
    source      = "0.0.0.0/0"

    udp_options {
      max = "53"
      min = "53"
    }
  }
}


data "oci_core_images" "latest_image" {
  compartment_id   = oci_identity_compartment.bedrockconnect.id
  shape            = var.shape
  operating_system = "Canonical Ubuntu"
  state            = "AVAILABLE"
  sort_by          = "TIMECREATED"
}

locals {
  cloudinit = yamlencode({
    packages : [
      "docker-compose"
    ]
    users : [
      {
        name : "cns"
        gecos : "Chris Nesbitt-Smith"
        sudo : "ALL=(ALL) NOPASSWD:ALL"
        groups : "docker"
        lock_passwd : "true"
        ssh_authorized_keys : [
          "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEA0sDxJBETSNFeRguPyde+tThCTXcYhbMUK/kx7Kn2thLQyuHWi5D7qqcQbgTOfnhJAYXYCY/G1jTvWIHue8moNyPHMoTzia4k7ENm/B6W0DtxKDIs4m++0A7zWHRd3Iaf49HSE8VRTGcAyz9cM4rvdj0AfO1m2SqBehe/8l6oA/M= cns@localhost"
        ]
      }
    ]
    write_files : [
      {
        path : "/root/dnsmasq-template.conf"
        content : file("./dnsmasq.conf")
      },
      {
        path : "/root/Dockerfile"
        content : file("./Dockerfile")
      },
      {
        path : "/root/docker-compose.yaml"
        content : file("./docker-compose.yaml")
      },
      {
        path : "/etc/cron.daily/keep-updated"
        content : file("./keep-updated.sh")
        permissions : "0755"
      }
    ]
    runcmd : [
      "systemctl stop systemd-resolved",
      "systemctl disable systemd-resolved",
      "rm /etc/resolv.conf",
      "echo nameserver 169.254.169.254 > /etc/resolv.conf",
      "EXTERNAL_IP=$(curl -s ifconfig.me) envsubst < /root/dnsmasq-template.conf > /root/dnsmasq.conf",
      "docker-compose -f /root/docker-compose.yaml up -d"
    ]
  })
}