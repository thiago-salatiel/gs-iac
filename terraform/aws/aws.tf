# Grupo de Segurança para permitir o tráfego HTTP e SSH
resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound traffic"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Criação das Instâncias EC2 em uma única zona de disponibilidade
resource "aws_instance" "web" {
  count                  = 2
  ami                    = "ami-02e136e904f3da870"
  instance_type          = "t2.micro"
  security_groups        = [aws_security_group.allow_http.name]
  availability_zone      = "us-east-1a"

  user_data = <<-EOF
              #!/bin/bash
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo 'Amém irmãos, deu certo!!!' > /var/www/html/index.html
              EOF

  tags = {
    Name = "web-${count.index}"
  }
}

# Load Balancer em uma única zona de disponibilidade
resource "aws_elb" "web_elb" {
  name               = "web-elb"
  availability_zones = ["us-east-1a"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

  instances                   = aws_instance.web.*.id
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "web-elb"
  }
}