data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "k3s_server" {
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = var.instance_type
  subnet_id                   = element([for s in aws_subnet.public : s.id], 0)
  vpc_security_group_ids      = [aws_security_group.k3s_nodes.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  # Note: Terraform heredoc delimiter is unquoted
  user_data = <<-CLOUDINIT
    #cloud-config
    package_update: true
    package_upgrade: true
    packages:
      - curl
      - ufw
    runcmd:
      - curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --write-kubeconfig-mode=0644" sh -
      - systemctl enable k3s
      - systemctl status k3s --no-pager || true
  CLOUDINIT

  tags = {
    Name = "${var.project_name}-k3s-server"
  }
}
