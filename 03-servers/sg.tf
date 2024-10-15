resource "aws_security_group" "bastion" {
  name   = "sg_bastion"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    from_port   = local.ssh_port
    to_port     = local.ssh_port
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_address]
  }

  egress {
    from_port   = local.http_port
    to_port     = local.http_port
    protocol    = "tcp"
    cidr_blocks = local.anywhere
  }

  egress {
    from_port   = local.https_port
    to_port     = local.https_port
    protocol    = "tcp"
    cidr_blocks = local.anywhere
  }

  tags = {
    Name = "bastion"
  }
}

resource "aws_security_group" "kubernetes_master" {
  name   = "sg_kubernetes_master"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    from_port   = local.ssh_port
    to_port     = local.ssh_port
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_address]
  }

  ingress {
    from_port   = local.kube_api_port
    to_port     = local.kube_api_port
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_address]
  }

  ingress {
    from_port   = local.hubble_port
    to_port     = local.hubble_port
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_address]
  }

  ingress {
    from_port   = local.kube_api_port
    to_port     = local.kube_api_port
    protocol    = "tcp"
    cidr_blocks = [for nat_ip in data.terraform_remote_state.network.outputs.aws_eip_nat_ip : "${nat_ip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = local.anywhere
  }

  tags = {
    Name = "Kubernetes master sg"
  }
}

resource "aws_security_group_rule" "master_ingress_bastion" {
  type                     = "ingress"
  from_port                = local.ssh_port
  to_port                  = local.ssh_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
  security_group_id        = aws_security_group.kubernetes_master.id
}

resource "aws_security_group_rule" "bastion_egress_master" {
  type                     = "egress"
  from_port                = local.ssh_port
  to_port                  = local.ssh_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.kubernetes_master.id
  security_group_id        = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "worker_ingress_bastion" {
  type                     = "ingress"
  from_port                = local.ssh_port
  to_port                  = local.ssh_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
  security_group_id        = aws_security_group.kubernetes_worker.id
}

resource "aws_security_group_rule" "bastion_egress_worker" {
  type                     = "egress"
  from_port                = local.ssh_port
  to_port                  = local.ssh_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.kubernetes_worker.id
  security_group_id        = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "master_ingress_worker" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.kubernetes_worker.id
  security_group_id        = aws_security_group.kubernetes_master.id
}

resource "aws_security_group" "kubernetes_worker" {
  name   = "sg_kubernetes_worker"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = local.anywhere
  }

  tags = {
    Name = "Kubernetes worker sg"
  }
}

resource "aws_security_group_rule" "master_to_worker" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.kubernetes_master.id
  security_group_id        = aws_security_group.kubernetes_worker.id
}

resource "aws_security_group_rule" "master_to_master" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.kubernetes_master.id
  security_group_id        = aws_security_group.kubernetes_master.id
}

resource "aws_security_group_rule" "worker_to_worker" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.kubernetes_worker.id
  security_group_id        = aws_security_group.kubernetes_worker.id
}

resource "aws_security_group_rule" "master_from_lb_internet" {
  type                     = "ingress"
  from_port                = local.kube_api_port
  to_port                  = local.kube_api_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lb_internet.id
  security_group_id        = aws_security_group.kubernetes_master.id
}

resource "aws_security_group_rule" "master_from_lb_api_internal" {
  type                     = "ingress"
  from_port                = local.kube_api_port
  to_port                  = local.kube_api_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lb_api_internal.id
  security_group_id        = aws_security_group.kubernetes_master.id
}

resource "aws_security_group_rule" "lb_api_internal_from_master" {
  type                     = "ingress"
  from_port                = local.kube_api_port
  to_port                  = local.kube_api_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.kubernetes_master.id
  security_group_id        = aws_security_group.lb_api_internal.id
}

resource "aws_security_group_rule" "worker_from_lb_api_internal" {
  type                     = "ingress"
  from_port                = local.kube_api_port
  to_port                  = local.kube_api_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lb_api_internal.id
  security_group_id        = aws_security_group.kubernetes_worker.id
}

resource "aws_security_group_rule" "lb_api_internal_from_worker" {
  type                     = "ingress"
  from_port                = local.kube_api_port
  to_port                  = local.kube_api_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.kubernetes_worker.id
  security_group_id        = aws_security_group.lb_api_internal.id
}

resource "aws_security_group_rule" "worker_from_lb_https" {
  type                     = "ingress"
  from_port                = local.nodeport_https
  to_port                  = local.nodeport_https
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lb_internet.id
  security_group_id        = aws_security_group.kubernetes_worker.id
}

resource "aws_security_group" "lb_internet" {
  name   = "sg_lb_internet"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    from_port   = local.kube_api_port
    to_port     = local.kube_api_port
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_address]
  }

  ingress {
    from_port   = local.https_port
    to_port     = local.https_port
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_address]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = local.anywhere
  }

  tags = {
    Name = "lb_internet_sg"
  }
}

resource "aws_security_group" "lb_api_internal" {
  name   = "sg_lb_api_internal"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = local.anywhere
  }

  tags = {
    Name = "lb_api_sg_internal"
  }
}
