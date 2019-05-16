###### 
###### Creación de entorno completo:
######    - VCN + Subnet + IGW
######    - DB System x2 con RAC primario y RAC standby !!!
######    - Compute nodes
######    - Load Balancer
######
variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "compartment_ocid" {}
variable "region" {}

provider "oci" {
  tenancy_ocid = "${var.tenancy_ocid}"
  user_ocid = "${var.user_ocid}"
  fingerprint = "${var.fingerprint}"
  private_key_path = "${var.private_key_path}"
  region = "${var.region}"
}

data "oci_identity_availability_domains" "ADs" {
  compartment_id = "${var.compartment_ocid}"
}

resource "oci_core_virtual_network" "sdunet" {
  cidr_block = "172.16.0.0/16"
  compartment_id = "${var.compartment_ocid}"
  display_name = "sdunet"
  dns_label = "sdunet"
}


###
### Internet Gateway !!!
###

resource "oci_core_internet_gateway" "sduigw" {
    compartment_id = "${var.compartment_ocid}"
    display_name = "sduigw"
    vcn_id = "${oci_core_virtual_network.sdunet.id}"
}


###
### Nueva Route table !!!
###

resource "oci_core_route_table" "internetroutetable" {
    compartment_id = "${var.compartment_ocid}"
    display_name = "InternetRouteTable"
    route_rules {
        cidr_block = "0.0.0.0/0"
        network_entity_id = "${oci_core_internet_gateway.sduigw.id}"
    }
    vcn_id = "${oci_core_virtual_network.sdunet.id}"
}


##
## Agregar una security list a la que viene por defecto
##    En esta vamos a agregar reglas de entrada a los puertos 80 y 8080 !!!
##    Esta Security List se la agregaremos a los Middleware que estan en las subnets ad1 y ad2 !!!
##

resource "oci_core_security_list" "sduadhocseclist" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id = "${oci_core_virtual_network.sdunet.id}"
  display_name = "Adhoc Security List for sdunet"

  // allow inbound tcp traffic from internet to port 80
  ingress_security_rules 
  {
    protocol = "6" // tcp
    source = "0.0.0.0/0"
    stateless = false
 tcp_options 
     {
      // These values correspond to the destination port range.
      "min" = 80
      "max" = 80
     }
  }

  // allow inbound tcp traffic from internet to port 8080
  ingress_security_rules 
  {
    protocol = "6" // tcp
    source = "0.0.0.0/0"
    stateless = false
 tcp_options 
     {
      // These values correspond to the destination port range.
      "min" = 8080
      "max" = 8080
     }
  }
}


resource "oci_core_security_list" "sdusqlnetseclist" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id = "${oci_core_virtual_network.sdunet.id}"
  display_name = "SQLNET Security List for sdunet"

  // allow inbound tcp traffic from internet to port 1521
  ingress_security_rules 
  {
    protocol = "6" // tcp
    source = "172.16.0.0/16" // Solo desde las maquinas de Middleware
    stateless = false
 tcp_options 
     {
      // These values correspond to the destination port range.
      "min" = 1521
      "max" = 1521
     }
  }

}

resource "oci_core_subnet" "sdunet-ad1" {
  compartment_id = "${var.compartment_ocid}"

  availability_domain = "${data.oci_identity_availability_domains.ADs.availability_domains.0.name}"
  route_table_id      = "${oci_core_route_table.internetroutetable.id}"
  vcn_id              = "${oci_core_virtual_network.sdunet.id}"
  security_list_ids   = ["${oci_core_virtual_network.sdunet.default_security_list_id}","${oci_core_security_list.sduadhocseclist.id}"]
  dhcp_options_id     = "${oci_core_virtual_network.sdunet.default_dhcp_options_id}"
  dns_label = "DNSLABEL1"
  display_name               = "sdunet-ad1"
  cidr_block                 = "172.16.1.0/24"
  prohibit_public_ip_on_vnic = false
}

resource "oci_core_subnet" "sdunet-ad2" {
  compartment_id = "${var.compartment_ocid}"

  availability_domain = "${data.oci_identity_availability_domains.ADs.availability_domains.1.name}"
  route_table_id      = "${oci_core_route_table.internetroutetable.id}"
  vcn_id              = "${oci_core_virtual_network.sdunet.id}"
  security_list_ids   = ["${oci_core_virtual_network.sdunet.default_security_list_id}","${oci_core_security_list.sduadhocseclist.id}"]
  dhcp_options_id     = "${oci_core_virtual_network.sdunet.default_dhcp_options_id}"
  dns_label = "DNSLABEL2"
  display_name               = "sdunet-ad2"
  cidr_block                 = "172.16.2.0/24"
  prohibit_public_ip_on_vnic = false
}

resource "oci_core_subnet" "sdunet-ad3" {
  compartment_id = "${var.compartment_ocid}"

  availability_domain = "${data.oci_identity_availability_domains.ADs.availability_domains.2.name}"
  route_table_id      = "${oci_core_virtual_network.sdunet.default_route_table_id}"
  vcn_id              = "${oci_core_virtual_network.sdunet.id}"
  security_list_ids   = ["${oci_core_virtual_network.sdunet.default_security_list_id}","${oci_core_security_list.sdusqlnetseclist.id}"]
  dhcp_options_id     = "${oci_core_virtual_network.sdunet.default_dhcp_options_id}"
  dns_label = "DNSLABEL3"
  display_name               = "sdunet-ad3"
  cidr_block                 = "172.16.3.0/24"
  prohibit_public_ip_on_vnic = false
}

