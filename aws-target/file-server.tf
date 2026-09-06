resource "aws_key_pair" "file_server" {
  key_name   = "${var.project_name}-file-server"
  public_key = file(pathexpand("~/.ssh/aws-migration-project-file.pub"))

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-file-server-key"
  })
}

data "aws_ami" "ubuntu_2404" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "file_server" {
  ami           = data.aws_ami.ubuntu_2404.id
  instance_type = "t3.small"

  subnet_id                   = aws_subnet.app_private_a.id
  vpc_security_group_ids      = [aws_security_group.file.id]
  associate_public_ip_address = false
  key_name                    = aws_key_pair.file_server.key_name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-file-server"
  })
}

