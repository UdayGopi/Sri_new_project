terraform { required_providers { aws = { source = "hashicorp/aws", version = "~> 4.0" } } }
provider "aws" { region = "us-east-1" }
variable "image_tag" { type = string }
locals { project_name = "sri-ai-app" }
resource "aws_ecr_repository" "app" { name = "${local.project_name}-repo" }
# ... (rest of terraform code for VPC, ECS, LB, etc. is identical to previous version) ...
resource "aws_vpc" "main" { cidr_block = "10.0.0.0/16"; tags = { Name = "${local.project_name}-vpc" } }
resource "aws_subnet" "public" { count = 2; vpc_id = aws_vpc.main.id; cidr_block = "10.0.${count.index + 1}.0/24"; availability_zone = "us-east-1${element(["a", "b"], count.index)}"; map_public_ip_on_launch = true; tags = { Name = "${local.project_name}-subnet-${count.index}" } }
resource "aws_internet_gateway" "main" { vpc_id = aws_vpc.main.id; tags = { Name = "${local.project_name}-igw" } }
resource "aws_route_table" "public" { vpc_id = aws_vpc.main.id; route { cidr_block = "0.0.0.0/0"; gateway_id = aws_internet_gateway.main.id; }; tags = { Name = "${local.project_name}-rt" } }
resource "aws_route_table_association" "public" { count = 2; subnet_id = aws_subnet.public[count.index].id; route_table_id = aws_route_table.public.id; }
resource "aws_security_group" "lb" { name = "${local.project_name}-lb-sg"; vpc_id = aws_vpc.main.id; ingress { from_port = 80; to_port = 80; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"]; }; egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"]; } }
resource "aws_security_group" "ecs" { name = "${local.project_name}-ecs-sg"; vpc_id = aws_vpc.main.id; ingress { from_port = 8080; to_port = 8080; protocol = "tcp"; security_groups = [aws_security_group.lb.id]; }; egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"]; } }
resource "aws_ecs_cluster" "main" { name = "${local.project_name}-cluster" }
resource "aws_ecs_task_definition" "app" { family = "${local.project_name}-task"; network_mode = "awsvpc"; requires_compatibilities = ["FARGATE"]; cpu = 256; memory = 512; container_definitions = jsonencode([{ name = local.project_name, image = "${aws_ecr_repository.app.repository_url}:${var.image_tag}", essential = true, portMappings = [{ containerPort = 8080, hostPort = 8080 }] }]) }
resource "aws_ecs_service" "main" { name = "${local.project_name}-service"; cluster = aws_ecs_cluster.main.id; task_definition = aws_ecs_task_definition.app.arn; desired_count = 2; launch_type = "FARGATE"; network_configuration { subnets = aws_subnet.public[*].id; security_groups = [aws_security_group.ecs.id]; assign_public_ip = true; }; load_balancer { target_group_arn = aws_lb_target_group.app.arn; container_name = local.project_name; container_port = 8080; } }
resource "aws_lb" "main" { name = "${local.project_name}-lb"; internal = false; load_balancer_type = "application"; security_groups = [aws_security_group.lb.id]; subnets = aws_subnet.public[*].id; }
resource "aws_lb_target_group" "app" { name = "${local.project_name}-tg"; port = 8080; protocol = "HTTP"; vpc_id = aws_vpc.main.id; health_check { path = "/api/health" } }
resource "aws_lb_listener" "http" { load_balancer_arn = aws_lb.main.arn; port = 80; protocol = "HTTP"; default_action { type = "forward"; target_group_arn = aws_lb_target_group.app.arn; } }
output "load_balancer_dns" { value = aws_lb.main.dns_name }