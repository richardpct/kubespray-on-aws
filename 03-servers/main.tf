resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = var.ssh_public_key
}

data "aws_ami" "amazonlinux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["137112412989"] # Amazon
}

data "aws_ami" "linux" {
  most_recent = true

  filter {
    name   = "name"
    values = [local.distribution == "ubuntu" ? "ubuntu-minimal/images/hvm-ssd-gp3/ubuntu-oracular-24.10-amd64-minimal-20241009" : "amazon/al2023-ami-*-kernel-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [local.distribution == "ubuntu" ? "099720109477" : "137112412989"]
}

resource "aws_eip" "bastion" {
  domain = "vpc"

  tags = {
    Name = "eip_bastion"
  }
}

resource "aws_launch_configuration" "bastion" {
  name                        = "bastion"
  image_id                    = data.aws_ami.linux.id
  user_data                   = templatefile("${local.distribution}/user-data-bastion.sh",
                                             { eip_bastion_id = aws_eip.bastion.id,
                                               region         = var.region,
                                               ssh_key        = var.ssh_bastion_private_key,
                                               archi          = local.archi,
                                               kubespray_vers = local.kubespray_vers
                                             })
  instance_type               = var.instance_type_bastion
  spot_price                  = local.bastion_price
  key_name                    = aws_key_pair.deployer.key_name
  security_groups             = [aws_security_group.bastion.id]
  iam_instance_profile        = aws_iam_instance_profile.profile.name
  associate_public_ip_address = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "bastion" {
  name                 = "asg_bastion"
  launch_configuration = aws_launch_configuration.bastion.id
  vpc_zone_identifier  = data.terraform_remote_state.network.outputs.subnet_public[*]
  min_size             = local.bastion_min
  max_size             = local.bastion_max

  tag {
    key                 = "Name"
    value               = "bastion"
    propagate_at_launch = true
  }
}

resource "aws_launch_configuration" "kubernetes_master" {
  name            = "Kubernetes master"
  image_id        = data.aws_ami.linux.id
  user_data       = templatefile("${local.distribution}/user-data-master.sh",
                                 { linux_user        = local.linux_user,
                                   archi             = local.archi,
                                   ssh_key           = var.ssh_nodes_public_key,
                                   kube_api_internet = aws_lb.internet.dns_name,
                                   kube_api_internal = aws_lb.api_internal.dns_name })
  instance_type   = var.instance_type_master
  spot_price      = local.master_price
  key_name        = aws_key_pair.deployer.key_name
  security_groups = [aws_security_group.kubernetes_master.id]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "kubernetes_master" {
  name                 = "Kubernetes master"
  launch_configuration = aws_launch_configuration.kubernetes_master.name
  vpc_zone_identifier  = data.terraform_remote_state.network.outputs.subnet_private[*]
  target_group_arns    = [aws_lb_target_group.api.arn, aws_lb_target_group.api_internal.arn]
  min_size             = local.master_min
  max_size             = local.master_max

  tag {
    key                 = "Name"
    value               = "kubernetes master"
    propagate_at_launch = true
  }
}

#resource "null_resource" "get_kube_config" {
#  provisioner "local-exec" {
#    command = <<EOF
#while ! nc -w1 ${aws_eip.bastion.public_ip} ${local.ssh_port}; do sleep 10; done
#ssh -o StrictHostKeyChecking=accept-new ${local.linux_user}@${aws_eip.bastion.public_ip} 'until [ -f /nfs/config ]; do sleep 10; done'
#ssh ${local.linux_user}@${aws_eip.bastion.public_ip} 'sed -e "s;https://.*:6443;https://${aws_lb.internet.dns_name}:6443;" /nfs/config' > ~/.kube/config-aws
#ssh ${local.linux_user}@${aws_eip.bastion.public_ip} 'sudo umount /nfs'
#chmod 600 ~/.kube/config-aws
#    EOF
#  }
#
#  depends_on = [aws_autoscaling_group.bastion]
#}

resource "null_resource" "clean_ssh_know_hosts" {
  provisioner "local-exec" {
    command = <<EOF
sed -i -e "/bastion.${var.my_domain}/d" ~/.ssh/known_hosts
    EOF
  }
  depends_on = [aws_autoscaling_group.bastion]
}

resource "aws_launch_configuration" "kubernetes_worker" {
  name            = "Kubernetes worker"
  image_id        = data.aws_ami.linux.id
  user_data       = templatefile("${local.distribution}/user-data-worker.sh",
                                 { archi   = local.archi,
                                   ssh_key = var.ssh_nodes_public_key
                                 })
  instance_type   = var.instance_type_worker
  spot_price      = local.worker_price
  key_name        = aws_key_pair.deployer.key_name
  security_groups = [aws_security_group.kubernetes_worker.id]

  ebs_block_device {
    device_name           = "/dev/sdb"
    volume_size           = var.longhorn_size_worker
    volume_type           = "gp2"
    delete_on_termination = true
  }

  root_block_device {
    volume_size           = var.root_size_worker
    delete_on_termination = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "kubernetes_worker" {
  name                 = "Kubernetes worker"
  launch_configuration = aws_launch_configuration.kubernetes_worker.name
  vpc_zone_identifier  = data.terraform_remote_state.network.outputs.subnet_private[*]
  target_group_arns    = [aws_lb_target_group.https.arn]
  min_size             = local.worker_min
  max_size             = local.worker_max

  tag {
    key                 = "Name"
    value               = "kubernetes worker"
    propagate_at_launch = true
  }
}
