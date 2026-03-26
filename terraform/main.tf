locals {
  name_prefix = "bookreview"
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "tls_private_key" "web_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "web_ssh" {
  content         = tls_private_key.web_ssh.private_key_pem
  filename        = "${path.module}/${var.private_key_filename}"
  file_permission = "0600"
}

resource "aws_key_pair" "web_ssh" {
  key_name   = var.generated_key_name
  public_key = tls_private_key.web_ssh.public_key_openssh
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-${count.index + 1}"
    Tier = "web"
  }
}

resource "aws_subnet" "app" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.app_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${local.name_prefix}-app-${count.index + 1}"
    Tier = "app"
  }
}

resource "aws_subnet" "db" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.db_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${local.name_prefix}-db-${count.index + 1}"
    Tier = "db"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "main" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${local.name_prefix}-nat-${count.index + 1}"
  }
}

resource "aws_route_table" "app_private" {
  count  = 2
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "${local.name_prefix}-app-private-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "app_private" {
  count          = 2
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app_private[count.index].id
}

resource "aws_route_table" "db_private" {
  count  = 2
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-db-private-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "db_private" {
  count          = 2
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db_private[count.index].id
}

resource "aws_security_group" "frontend_alb" {
  name        = "${local.name_prefix}-frontend-alb-sg"
  description = "Allow public HTTP access to the frontend ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
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

resource "aws_security_group" "web" {
  name        = "${local.name_prefix}-web-sg"
  description = "Allow ALB and admin SSH access to the frontend instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from frontend ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_alb.id]
  }

  ingress {
    description = "Admin SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "backend_alb" {
  name        = "${local.name_prefix}-backend-alb-sg"
  description = "Allow only web tier traffic to the internal backend ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Backend traffic from web tier"
    from_port       = 3001
    to_port         = 3001
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app" {
  name        = "${local.name_prefix}-app-sg"
  description = "Allow only backend ALB traffic to the app instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App traffic from backend ALB"
    from_port       = 3001
    to_port         = 3001
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db" {
  name        = "${local.name_prefix}-db-sg"
  description = "Allow MySQL only from the app tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from app tier"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "frontend" {
  name               = "bookreview-frontend-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.frontend_alb.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "frontend" {
  name     = "bookreview-fe-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }
}

resource "aws_lb_listener" "frontend_http" {
  load_balancer_arn = aws_lb.frontend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb" "backend" {
  name               = "bookreview-backend-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.backend_alb.id]
  subnets            = aws_subnet.app[*].id
}

resource "aws_lb_target_group" "backend" {
  name     = "bookreview-be-tg"
  port     = 3001
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }
}

resource "aws_lb_listener" "backend_http" {
  load_balancer_arn = aws_lb.backend.arn
  port              = 3001
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "bookreview-db-subnet-group"
  subnet_ids = aws_subnet.db[*].id
}

resource "aws_db_instance" "primary" {
  identifier                 = "bookreview-mysql-primary"
  allocated_storage          = 20
  max_allocated_storage      = 100
  engine                     = "mysql"
  instance_class             = var.db_instance_class
  db_name                    = var.db_name
  username                   = var.db_username
  password                   = var.db_password
  db_subnet_group_name       = aws_db_subnet_group.main.name
  vpc_security_group_ids     = [aws_security_group.db.id]
  multi_az                   = true
  publicly_accessible        = false
  storage_encrypted          = true
  backup_retention_period    = 1
  skip_final_snapshot        = true
  deletion_protection        = false
  apply_immediately          = true
  auto_minor_version_upgrade = true
}

resource "aws_db_instance" "replica" {
  identifier                 = "bookreview-mysql-replica"
  replicate_source_db        = aws_db_instance.primary.arn
  instance_class             = var.db_instance_class
  publicly_accessible        = false
  db_subnet_group_name       = aws_db_subnet_group.main.name
  vpc_security_group_ids     = [aws_security_group.db.id]
  auto_minor_version_upgrade = true
  depends_on                 = [aws_db_instance.primary]
}

resource "aws_launch_template" "web" {
  name_prefix   = "bookreview-web-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.web_instance_type
  key_name      = aws_key_pair.web_ssh.key_name

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web.id]
  }

  user_data = base64encode(templatefile("${path.module}/frontend_user_data.sh.tpl", {
    repo_url        = var.repo_url
    public_api_url  = "http://${aws_lb.frontend.dns_name}"
    backend_alb_dns = aws_lb.backend.dns_name
  }))

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "bookreview-web"
      Tier = "web"
    }
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "bookreview-app-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.app_instance_type

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.app.id]
  }

  user_data = base64encode(templatefile("${path.module}/backend_user_data.sh.tpl", {
    repo_url        = var.repo_url
    db_host         = aws_db_instance.primary.address
    db_name         = var.db_name
    db_user         = var.db_username
    db_password     = var.db_password
    jwt_secret      = var.jwt_secret
    allowed_origins = "http://${aws_lb.frontend.dns_name},http://localhost:3000"
  }))

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "bookreview-app"
      Tier = "app"
    }
  }
}

resource "aws_autoscaling_group" "web" {
  name                      = "bookreview-web-asg"
  min_size                  = var.web_desired_capacity
  max_size                  = var.web_desired_capacity
  desired_capacity          = var.web_desired_capacity
  vpc_zone_identifier       = aws_subnet.public[*].id
  health_check_type         = "ELB"
  health_check_grace_period = 300
  target_group_arns         = [aws_lb_target_group.frontend.arn]

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "bookreview-web"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "app" {
  name                      = "bookreview-app-asg"
  min_size                  = var.app_desired_capacity
  max_size                  = var.app_desired_capacity
  desired_capacity          = var.app_desired_capacity
  vpc_zone_identifier       = aws_subnet.app[*].id
  health_check_type         = "ELB"
  health_check_grace_period = 300
  target_group_arns         = [aws_lb_target_group.backend.arn]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "bookreview-app"
    propagate_at_launch = true
  }
}