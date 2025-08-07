resource "proxmox_vm_qemu" "wordpress_vm" {
  name        = "wordpress-${var.instance_name}"
  target_node = var.target_node
  clone       = var.template_name
  full_clone  = true
  cores       = 2
  memory      = 2048
  sockets     = 1
  scsihw      = "virtio-scsi-pci"
  agent       = 1

  network {
    model = "virtio"
    bridge = "vmbr0"
  }

  disk {
    size = "20G"
  }

  ipconfig0 = "ip=${var.ip_address}/24,gw=${var.gateway}"

  sshkeys = file("~/.ssh/id_rsa.pub")
}
