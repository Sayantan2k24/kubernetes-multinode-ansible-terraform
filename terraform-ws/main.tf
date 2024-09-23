# VPC
# Using the default VPC 
resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

# Declare the data source
# Accessing the list of AWS Availability Zones within the same region
data "aws_availability_zones" "available" {}

# Subnet
# Using the Default Subnet of the First AZ
# As I am using the region ap-south-1 --> so the first az is --> ap-south-1a
resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "Default subnet for ${data.aws_availability_zones.available.names[0]}"

  }
}

# create Common security group for all the servers
# set the neccesary ingress rules for k8s cluster
# 
# To use it later in other main.tf files --> 

# data "aws_security_group" "existing_sg" {
#   filter {
#     name   = "tag:Name"
#     values = ["secure-sg"]
#   }
# }

resource "aws_security_group" "secure-sg" {
  name        = "secure-sg"
  description = "Allow necessary inbound traffic"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    description = "SMTP"
    from_port   = 25
    to_port     = 25
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "App_deployments"
    from_port   = 3000
    to_port     = 10000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "K8s-apiServer"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SMTPS"
    from_port   = 465
    to_port     = 465
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NodePort-Services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ping"
    from_port   = 0
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "secure-sg"
  }
}

# create ssh key in AWS
resource "aws_key_pair" "server-key" {
  key_name   = "boardgame-servers-key"
  public_key = file("../keys/id_rsa.pub")
}

# Create ec2 instance for k8s master node with the ssh key
resource "aws_instance" "k8s_master" {
  ami                    = "ami-05a5bb48beb785bf1"
  instance_type          = "t2.medium"
  subnet_id              = aws_default_subnet.default_az1.id
  vpc_security_group_ids = [aws_security_group.secure-sg.id]
  key_name               = aws_key_pair.server-key.key_name
  root_block_device {
    volume_size           = 10
    delete_on_termination = "true"
  }

  tags = {
    Name = "k8s-master"
  }

}



# Create ec2 instances for k8s slaves
resource "aws_instance" "k8s_slaves" {
  count                  = 2
  ami                    = "ami-05a5bb48beb785bf1"
  instance_type          = "t2.medium"
  subnet_id              = aws_default_subnet.default_az1.id
  vpc_security_group_ids = [aws_security_group.secure-sg.id]
  key_name               = aws_key_pair.server-key.key_name
  root_block_device {
    volume_size           = 10
    delete_on_termination = true
  }

  tags = {
    Name = "k8s-slave-${count.index + 1}"
  }
}

# Retrieve the public IP address of the master node
output "k8s_master_public_ip" {
  value = aws_instance.k8s_master.public_ip
}


# Retrieve the public IP address of the slave node 1
output "k8s_slave_1_public_ip" {
  value = aws_instance.k8s_slaves[0].public_ip
}

# Retrieve the public IP address of the slave node 2
output "k8s_slave_2_public_ip" {
  value = aws_instance.k8s_slaves[1].public_ip
}



# Now we will configure the trigger to ansible
# First create the inventory
resource "local_file" "inventory_creation" {
  depends_on = [
    aws_instance.k8s_master,
    aws_instance.k8s_slaves
  ]

  # Write the ansible inventory to a file
  content  = <<-EOF
      [k8s-master]
      ${aws_instance.k8s_master.public_ip} ansible_user=ec2-user ansible_ssh_private_key_file=../keys/id_rsa

      [k8s-slaves]
      ${aws_instance.k8s_slaves[0].public_ip} ansible_user=ec2-user ansible_ssh_private_key_file=../keys/id_rsa
      ${aws_instance.k8s_slaves[1].public_ip} ansible_user=ec2-user ansible_ssh_private_key_file=../keys/id_rsa
  EOF
  filename = "../ansible-ws/inventory"
}

# Configure the ansible.cfg 
resource "local_file" "configure_ansible_cfg" {
  depends_on = [
    aws_instance.k8s_master,
    aws_instance.k8s_slaves,
    local_file.inventory_creation
  ]

  # Write the ansible.cfg file
  content  = <<-EOF
      [defaults]
      host_key_checking=False
      inventory=./inventory
      remote_user=ec2-user
      private_key_file=../keys/id_rsa
      ask_pass=false
      deprecation_warnings=False

      [privilege_escalation]
      become=true
      become_method=sudo
      become_user=root
      become_ask_pass=false
  EOF
  filename = "../ansible-ws/ansible.cfg"
}


# Trigger ansible to run rhel_common.yml
resource "null_resource" "trigger_ansible_playbook_common" {
  depends_on = [
    aws_instance.k8s_master,
    aws_instance.k8s_slaves,
    local_file.inventory_creation,
    local_file.configure_ansible_cfg
  ]

  provisioner "local-exec" {
    working_dir = "../ansible-ws/"
    command     = "ansible-playbook rhel_common.yml"
  }
}

# Trigger ansible to run rhel_master.yml
resource "null_resource" "trigger_ansible_playbook_master" {
  depends_on = [
    aws_instance.k8s_master,
    aws_instance.k8s_slaves,
    local_file.inventory_creation,
    local_file.configure_ansible_cfg,
    null_resource.trigger_ansible_playbook_common
  ]

  provisioner "local-exec" {
    working_dir = "../ansible-ws/"
    command     = "ansible-playbook rhel_master.yml"
  }
}




