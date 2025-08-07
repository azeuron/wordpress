# Self-hosted WordPress project

# 1️⃣ Directory Structure

   ```css
   homelab-wordpress/
   ├── README.md
   ├── .gitignore
   ├── terraform/
   │   ├── provider.tf
   │   ├── main.tf
   │   ├── variables.tf
   │   ├── terraform.tfvars.example
   ├── ansible/
   │   ├── inventory.ini.example
   │   ├── playbook.yml
   │   ├── group_vars/
   │   │   └── wordpress.yml
   │   ├── vault_pass.txt (OPTIONAL, never commit)
   ```

---

# 2️⃣.gitignore
Ensures you never commit private info:
   ```bash
   # Terraform sensitive files
   terraform.tfstate
   terraform.tfstate.backup
   *.tfvars
   *.tfstate.lock.info

   # Ansible sensitive files
   ansible/inventory.ini
   ansible/vault_pass.txt

   # Temporary files
   *.retry
   *.log
   __pycache__/
   ```
✅ **This ensures passwords, SSH keys, and state files with IP addresses never reach GitHub.

---

# 3️⃣ README.md

Provides instructions for future me.

   ```markdown
# Homelab WordPress Deployment (Terraform + Ansible)

This repo deploys a WordPress VM in Proxmox using Terraform and configures it with Ansible.

## Steps:

1. Copy example variable files:
      ```bash
      cp terraform/terraform.tfvars.example terraform/terraform.tfvars
      cp ansible/inventory.ini.example ansible/inventory.ini
      ```

2. Edit the files to set your Proxmox host, credentials, and IPs.


3. Initialize Terraform:
      ```bash
      cd terraform
      terraform init
      terraform apply
      ```

4. Configure with Ansible:
      ```bash
      cd ../ansible
      ansible-playbook -i inventory.ini playbook.yml
      ```

   ---
   
   # **4️⃣ Terraform Files**

   ### `provider.tf`
      ```hcl
      terraform {
        required_providers {
          proxmox = {
            source  = "Telmate/proxmox"
            version = "2.9.11"
          }
        }
      }

      provider "proxmox" {
        pm_api_url      = "https://<proxmox-host>:8006/api2/json"
        pm_user         = "root@pam"
        pm_password     = var.pm_password
        pm_tls_insecure = true
      }
      ```

   ---

   main.tf
      ```hcl
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
       ```

   ---

   variables.tf
      ```hcl
      variable "pm_password" {
     sensitive = true
      }

      variable "target_node" {}
      variable "template_name" {}
      variable "instance_name" {}
      variable "ip_address" {}
      variable "gateway" {
        default = "192.168.1.1"
      }
         ```

   ---

   terraform.tfvars.example
      ```hcl
      pm_password    = "changeme"
   target_node    = "pve"
   template_name  = "debian-docker-template"
   instance_name  = "blog1"
   ip_address     = "192.168.1.50"
      ```
   > ✅*Note:* You copy this to `terraform.tfvars` locally and **never commit** the real one. 

   ---


   # **5️⃣ Ansible Files**

   `inventory.ini.example`
      ```ini
      [wordpress]
      192.168.1.50 ansible_user=debian ansible_ssh_private_key_file=~/.ssh/id_rsa
      ```

   Copy to `inventory.ini` locally and update IPs.

   ---

   `group_vars/wordpress.yml`
      ```yaml
      mysql_database: wordpress
      mysql_user: wpuser
      wordpress_port: 8080
      ```
   > Defaults only, no passwords stored here.

   ---

   `playbook.yml`
      ```yaml
   - hosts: wordpress
     become: yes
     vars:
       mysql_password_file: /tmp/mysql_pass
       mysql_root_password_file: /tmp/root_pass
     tasks:
       - name: Install dependencies
         apt:
           name:
             - docker.io
             - docker-compose
             - git
           state: present
           update_cache: yes

       - name: Clone WordPress repo
         git:
           repo: 'git@github.com:yourusername/your-wordpress-repo.git'
           dest: /home/debian/wordpress
           version: main

       - name: Generate MySQL password if missing
         command: openssl rand -base64 16
         register: mysql_password
         args:
           creates: "{{ mysql_password_file }}"
         changed_when: mysql_password.rc == 0
       - copy:
           dest: "{{ mysql_password_file }}"
           content: "{{ mysql_password.stdout }}"
         when: mysql_password.stdout is defined

       - name: Generate MySQL root password if missing
         command: openssl rand -base64 20
         register: mysql_root_password
         args:
           creates: "{{ mysql_root_password_file }}"
         changed_when: mysql_root_password.rc == 0
       - copy:
           dest: "{{ mysql_root_password_file }}"
           content: "{{ mysql_root_password.stdout }}"
         when: mysql_root_password.stdout is defined

       - name: Create .env file for Docker
         template:
           dest: /home/debian/wordpress/.env
           mode: '0600'
           src: env.j2

       - name: Start WordPress containers
         command: docker-compose up -d
         args:
           chdir: /home/debian/wordpress
      ```

   ---

   `templates/env.j2`
      ```jinja2
      MYSQL_DATABASE={{ mysql_database }}
      MYSQL_USER={{ mysql_user }}
      MYSQL_PASSWORD={{ lookup('file', mysql_password_file) }}
      MYSQL_ROOT_PASSWORD={{ lookup('file', mysql_root_password_file) }}
      WORDPRESS_DB_HOST=db:3306
      WORDPRESS_DB_USER={{ mysql_user }}
      WORDPRESS_DB_PASSWORD={{ lookup('file', mysql_password_file) }}
      WORDPRESS_DB_NAME={{ mysql_database }}
      ```

   ---

   # **6️⃣  Deployment Steps**

   1. Clone your repo locally:
      ```bash
      git clone git@github.com:yourusername/homelab-wordpress.git
      ```

   2. Set local variables:
      ```bash
      cp terraform/terraform.tfvars.example terraform/terraform.tfvars
      cp ansible/inventory.ini.example ansible/inventory.ini
      ```
   Edit both files with your real values.
   3. Deploy VM:
      ```bash
      cd terraform
      terraform init
      terraform apply
      ```

   4. Configure VM:
      ```bash
      cd ../ansible
      ansible-playbook -i inventory.ini playbook.yml
      ```

   5. Access blog: http://<VM-IP>:8080

   ---

   # ✅ **Key Security Measures**

   - No passwords or sensitive files (`terraform.tfvars`, `inventory.ini`, SSH keys, Ansible generated passwords) are ever in GitHub.
   - `.gitignore` covers all secrets and Terraform state.
   - Passwords are generated on first run and stored only on the VM and your local machine, not in code.
   - SSH keys are referenced by path, not copied to the repo.

      ```
