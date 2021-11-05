resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "aws_key_pair" "kp" {
  key_name = "myKey"
  public_key = tls_private_key.pk.public_key_openssh

  provisioner "local-exec" {
    command = "echo '${tls_private_key.pk.private_key_pem}' > ./myKey.pem"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
      name = "name"
      values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
      name = "virtualization-type"
      values = ["hvm"]
  }
  owners = ["099720109477"]
}

resource "aws_security_group" "allow_inbound_http" {
  name        = "allow-inbound-http"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_inbond_ssh" {
  name = "allow-inbond-ssh"

  ingress {
    cidr_blocks = [ "0.0.0.0/0" ]
    from_port = 22
    protocol = "tcp"
    to_port = 22
  }
}

resource "aws_security_group" "allow_outbound_traffic" {
  name        = "allow-outbound-traffic"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "l1nginx" {
  ami = data.aws_ami.ubuntu.id
  key_name = aws_key_pair.kp.key_name
  instance_type = "t2.micro"

#  user_data = "${file("nginx.sh")}"

  provisioner "remote-exec" {
  connection {
      host = aws_instance.l1nginx.public_ip
      user = "ubuntu"
      private_key = tls_private_key.pk.private_key_pem
  }
    inline = [
        "sudo apt update",
        "sudo apt -y install nginx",
        "sudo service nginx start",
    ]
  }


  tags = {
      name = "Lesson1nginx"
  }

  vpc_security_group_ids = [
      aws_security_group.allow_inbound_http.id,
      aws_security_group.allow_inbond_ssh.id,
      aws_security_group.allow_outbound_traffic.id,
  ]
}