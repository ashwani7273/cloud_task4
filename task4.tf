provider "aws"{
    region="ap-south-1"
    profile="ashwani"
}

resource "aws_vpc" "task_vpc" {
  cidr_block = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true
tags = {
  Name = "task_vpc"
 }
}

resource "aws_subnet" "public_subnet" {
  vpc_id     = "${aws_vpc.task_vpc.id}"
  cidr_block = "192.168.10.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = "true"
tags = {
    Name = "public_subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id     = "${aws_vpc.task_vpc.id}"
  cidr_block = "192.168.11.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = "true"
tags = {
    Name = "private_subnet"
  }
}

resource "aws_internet_gateway" "task_gateway" {
  vpc_id = "${aws_vpc.task_vpc.id}"
tags = {
    Name = "task_gateway"
  }
}

resource "aws_route_table" "task_route" {
  vpc_id = "${aws_vpc.task_vpc.id}"
  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.task_gateway.id
     }
tags = {
                Name = "task_route"
          }
}

resource "aws_route_table_association" "rt_association" {
  subnet_id         = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.task_route.id
}

resource "aws_eip" "task_eip" {
  vpc=true
}


resource "aws_nat_gateway" "task_nat" {
  allocation_id = aws_eip.task_eip.id
  subnet_id     = aws_subnet.public_subnet.id


  tags = {
    Name = "task_nat"
  }
}

resource "aws_route_table" "task_route_secure" {
  vpc_id = "${aws_vpc.task_vpc.id}"
  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.task_gateway.id
     }
tags = {
                Name = "task_route_secure"
          }
}



resource "aws_route_table_association" "rt1_association" {
  subnet_id         = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.task_route_secure.id
}

resource "aws_security_group" "wordpress_sg" {
  name        = "wordpress_sg"
  description = "Allow ssh-22,http-80 protocols and NFS inbound traffic"
  vpc_id = "${aws_vpc.task_vpc.id}"
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
  ingress {
    description = "TCP"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wordpress_sg"
  }
}

resource "aws_security_group" "bastion_host" {
  name        = "bastion_host"
  description = "Bastion host"
  vpc_id      = aws_vpc.task_vpc.id


  ingress {
    description = "ssh"
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




  tags = {
    Name ="bastion_host"
  }
}

resource "aws_security_group" "mysql_sg" {
  name = "mysql_sg"
  vpc_id = "${aws_vpc.task_vpc.id}"
  ingress {
    protocol        = "tcp"
    from_port       = 3306
    to_port         = 3306
    security_groups = ["${aws_security_group.wordpress_sg.id}"]
  }
 egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags ={
    Name= "mysql_sg"
  }
}

resource "aws_security_group" "bashion_permit" {
  name        = "bashion_permit"
  description = "Bastion Permission Granted"
  vpc_id      = aws_vpc.task_vpc.id




ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion_host.id]
  }
  
 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
}




  tags = {
    Name ="bashion_permit"
  }
}

resource "tls_private_key" "task_keypair" {
  algorithm   = "RSA"
}
output "ssh_key" {
    value = tls_private_key.task_keypair.public_key_openssh
}

output "pem_key" {
     value = tls_private_key.task_keypair.public_key_pem
}

resource "aws_key_pair" "task_keypair"{
      key_name = "task_keypair"
      public_key = tls_private_key.task_keypair.public_key_openssh
}


resource "aws_instance" "task_wp" {
  ami           = "ami-000cbce3e1b899ebd"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  key_name =    aws_key_pair.task_keypair.key_name
  vpc_security_group_ids = [aws_security_group.wordpress_sg.id]
   subnet_id = aws_subnet.public_subnet.id
tags = {
    Name = "task_wp"
  }
}

resource "aws_instance" "task_sql" {
  ami           = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  key_name =    aws_key_pair.task_keypair.key_name
  vpc_security_group_ids = [aws_security_group.mysql_sg.id , aws_security_group.bashion_permit.id]
   subnet_id = aws_subnet.private_subnet.id
tags = {
    Name = "task_sql"
  }
}

  output "wp_ip" {
    value = aws_instance.task_wp.public_ip
}

  output "mysql_ip" {
    value = aws_instance.task_sql.public_ip
}

resource "null_resource" "os_ip" {
  provisioner "local-exec" {
   command = "echo  ${aws_instance.task_wp.public_ip} > wppublicip.txt"
   //command = "echo  ${aws_instance.task_sql.private_ip} > sqlprivateip.txt"
  	}
}