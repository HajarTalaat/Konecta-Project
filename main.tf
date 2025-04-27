provider "aws" {
  region = "us-east-1"
}

data "aws_vpc" "existing_vpc" {
  id = "vpc-0609b7dccf0d5023e"
}

data "aws_subnet" "public_subnet" {
  id = "subnet-03f3abb73cad7daf2"
}

data "aws_subnet" "private_subnet_1" {
  id = "subnet-036ef676e07c08cd0"
}

data "aws_subnet" "private_subnet_2" {
  id = "subnet-09893ebb6b855f5a4"
}

resource "aws_key_pair" "deployer" {
  key_name   = "terraform-key"
  public_key = file("~/.ssh/terraform-key.pub")
}

resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Allow SSH and Jenkins UI"
  vpc_id      = data.aws_vpc.existing_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "jenkins" {
  ami                         = "ami-07c17beb0cc086f4f"
  instance_type               = "t3.large"
  subnet_id                   = data.aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  key_name                    = aws_key_pair.deployer.key_name
  associate_public_ip_address = true

  tags = {
    Name = "jenkins-ec2"
  }
}

data "aws_internet_gateway" "existing" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.existing_vpc.id]
  }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = data.aws_subnet.public_subnet.id
  depends_on    = [data.aws_internet_gateway.existing]
}

resource "aws_route_table" "private_rt" {
  vpc_id = data.aws_vpc.existing_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route_table_association" "private_assoc1" {
  subnet_id      = data.aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_assoc2" {
  subnet_id      = data.aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}

resource "null_resource" "provision_jenkins_with_ansible" {
  depends_on = [aws_instance.jenkins]

  triggers = {
    jenkins_ip = aws_instance.jenkins.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'SSH to Jenkins EC2 at ${aws_instance.jenkins.public_ip} succeeded'"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = aws_instance.jenkins.public_ip
      private_key = file("~/.ssh/terraform-key")
      timeout     = "5m"
    }
  }

  provisioner "local-exec" {
    command = <<EOT
echo "Updating Ansible inventory with ${aws_instance.jenkins.public_ip}..."
sed "s/{{ jenkins_public_ip }}/${aws_instance.jenkins.public_ip}/g" ~/terraform/ansible/inventory.tpl > ~/terraform/ansible/inventory.ini

echo "Running Ansible playbook..."
cd ~/terraform/
bash scripts/run_ansible.sh
EOT
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.35.0"

  cluster_name    = "devops-grad-eks"
  cluster_version = "1.27"
  vpc_id          = data.aws_vpc.existing_vpc.id
  subnet_ids      = [data.aws_subnet.private_subnet_1.id, data.aws_subnet.private_subnet_2.id]

  enable_irsa                          = true
  cluster_endpoint_private_access      = false
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

  eks_managed_node_group_defaults = {
    instance_types = ["t3.medium"]
  }

  eks_managed_node_groups = {
    node_group = {
      desired_capacity = 2
      max_capacity     = 2
      min_capacity     = 1
    }
  }

  tags = {
    Environment = "devops-grad"
  }
}


resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Allow SSH from Terraform EC2 into private bastion"
  vpc_id      = data.aws_vpc.existing_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["172.31.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "bastion_role" {
  name = "bastion-eks-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "bastion_eks_policy" {
  name        = "bastion-eks-describe-cluster"
  description = "Allow eks:DescribeCluster for kubeconfig"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["eks:DescribeCluster"],
    "Resource": "*"
  }]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "bastion_eks_attach" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = aws_iam_policy.bastion_eks_policy.arn
}

resource "aws_iam_instance_profile" "bastion_profile" {
  name = "bastion-eks-profile"
  role = aws_iam_role.bastion_role.name
}

resource "aws_instance" "bastion" {
  ami                         = "ami-084568db4383264d4"
  instance_type               = "t3.small"
  subnet_id                   = data.aws_subnet.private_subnet_1.id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  key_name                    = aws_key_pair.deployer.key_name
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.bastion_profile.name

  tags = {
    Name = "eks-bastion"
  }
}
