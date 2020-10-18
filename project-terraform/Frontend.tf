# VPC Module
module "vpc" {
  source = "git::https://github.com/SeungHyeonShin/terraform.git//modules/vpc?ref=v0.0.4"

  aws_vpc_cidr        = "10.0.0.0/16"
  aws_private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  aws_public_subnets  = ["10.0.11.0/24", "10.0.12.0/24"]
  aws_region          = "ap-northeast-2"
  aws_azs             = ["ap-northeast-2a", "ap-northeast-2c"]

  global_tags = "seunghyeon"
}

# Security Group
## Bastion Host Security Group
resource "aws_security_group" "seunghyeon-bastion-sg" {
  name = "seunghyeon-bastion"
  vpc_id = module.vpc.aws_vpc_id

  ingress {
    from_port = 22
    protocol = "tcp"
    to_port = 22
    cidr_blocks = var.MyIpAddress
  }

  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "seunghyeon-bastion-sg"
  }
}
## EC2 Security Group
resource "aws_security_group" "seunghyeon-ec2" {
  name = "seunghyeon-ec2"
  vpc_id = module.vpc.aws_vpc_id

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 2049
    to_port = 2049
    protocol = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    security_groups = [aws_security_group.seunghyeon-bastion-sg.id]
  }

  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "seunghyeon-ec2"
  }
}
## NLB Security Group
resource "aws_security_group" "alb" {
  name = "seunghyeon-nlb"
  vpc_id = module.vpc.aws_vpc_id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "seunghyeon-nlb"
  }
}

# Create EC2 Autoscaling Groups
resource "aws_launch_configuration" "seunghyeon-lanch-config" {
  image_id = "ami-0991ffface16fe177"
  instance_type = "t3.medium"
  key_name = aws_key_pair.seunghyeon-ec2.id
  security_groups = [aws_security_group.seunghyeon-ec2.id]
  user_data = <<-EOF
              #!bin/bash
              mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 10.0.1.181:/ /home/ec2-user/quickstart
              su - ec2-user -c "echo cd /home/ec2-user/quickstart" > /home/ec2-user/a.sh && su - ec2-user -c "echo hugo server -D -p 8080 --bind 0.0.0.0" >> /home/ec2-user/a.sh
              chmod +x /home/ec2-user/a.sh && chmod +x /home/ec2-user/compare/autoup.sh
              sleep 10
              su - ec2-user -c "sh /home/ec2-user/a.sh"
              EOF
  lifecycle {
    create_before_destroy = true #항상 기존 리소스가 삭제되기 전에 새로운 리소스를 생성한다.
  }
  # 설정안하면 없는 보안그룹의 ID가 설정됨
  depends_on = [aws_security_group.seunghyeon-ec2]
}
resource "aws_autoscaling_group" "seunghyeon-ec2" {
  launch_configuration = aws_launch_configuration.seunghyeon-lanch-config.id
  vpc_zone_identifier = [module.vpc.private_subnets.0]
  target_group_arns = [aws_lb_target_group.seunghyeon-target.arn]
  force_delete = true


  # Health Check
  health_check_type = "ELB"
  health_check_grace_period = 100
  max_size = 5
  min_size = 1

  tag {
    key     = "Name"
    value   = "seunghyeon-EC2"

    propagate_at_launch = true
  }
}
# Create Bastion Host
resource "aws_instance" "bastion" {
  ami = "ami-027ce4ce0590e3c98"
  instance_type = "t2.micro"
  subnet_id = element(module.vpc.public_subnets, 0)
  key_name = aws_key_pair.seunghyeon-bastion.id
  vpc_security_group_ids = [
    aws_security_group.seunghyeon-bastion-sg.id
  ]

  tags = {
    "Name" = "seunghyeon-BastionHost"
  }
}
# Setting Autoscaling Policy
resource "aws_autoscaling_policy" "seunghyeon-scale_inout" {
  autoscaling_group_name = aws_autoscaling_group.seunghyeon-ec2.name
  name = "seunghyeon-scale_inout"
  policy_type = "TargetTrackingScaling"
  adjustment_type = "ChangeInCapacity"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# Create ALB
resource "aws_lb" "seunghyeon-lb" {
  name = "seunghyeon-alb"
  internal = false
  load_balancer_type = "application"
  subnets = module.vpc.public_subnets
  security_groups = [aws_security_group.alb.id]
  tags = {
    "Name" = "seunghyeon-lb"
  }
}
resource "aws_lb_listener" "seunghyeon-listener" {
  load_balancer_arn = aws_lb.seunghyeon-lb.arn
  port = 80
  protocol = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.seunghyeon-target.arn
    type = "forward"
  }
}
resource "aws_lb_target_group" "seunghyeon-target" {
  name = "seunghyeon-target-group"
  port = 8080
  protocol = "HTTP"
  vpc_id = module.vpc.aws_vpc_id
}
resource "aws_lb_listener_rule" "seunghyeon-rule" {
  listener_arn = aws_lb_listener.seunghyeon-listener.arn
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.seunghyeon-target.arn
  }
  condition {
    path_pattern {
      values = ["/"]
    }
  }
}

# Create Cloud Front
resource "aws_cloudfront_distribution" "seunghyeon-cloudfront" {
  enabled = true
  default_cache_behavior {
    allowed_methods = ["GET", "HEAD"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = "seunghyeon-project"
    viewer_protocol_policy = "allow-all"
    forwarded_values {
      query_string = false
      headers = [
        "Origin",
        "Access-Control-Request-Headers",
        "Access-Control-Request-Method"
      ]
      cookies {
        forward = "none"
      }
    }
  }
  origin {
    domain_name = "aws-mediaconvert1-output.s3.amazonaws.com"
    origin_id = "seunghyeon-project"
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.seunghyeon-origin-access.cloudfront_access_identity_path
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  retain_on_delete = false
}
resource "aws_cloudfront_origin_access_identity" "seunghyeon-origin-access" {
  comment = "seunghyeonshin's-access"
}
## Set S3 Bucket Policy to Access Cloud Front
data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.transcoded.arn}/*"]
    effect = "Allow"
    principals {
      identifiers = ["*"]
      type = "*"
    }
  }
  statement {
    actions = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.transcoded.arn}/*"]

    principals {
      identifiers = [aws_cloudfront_origin_access_identity.seunghyeon-origin-access.iam_arn]
      type = "AWS"
    }
  }
}
resource "aws_s3_bucket_policy" "example" {
  bucket = aws_s3_bucket.transcoded.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

# Create Route53
resource "aws_route53_zone" "seunghyeon-route53" {
  name = "seunghyeon-project.shop"

  tags = {
    "Name" = "seunghyeon-route53"
  }
}
resource "aws_route53_record" "seunghyeon-route53-record" {
  name = format(aws_route53_zone.seunghyeon-route53.name)
  type = "A"
  zone_id = aws_route53_zone.seunghyeon-route53.id

  alias {
    evaluate_target_health = true
    name = format("%s.%s", "dualstack", aws_lb.seunghyeon-lb.dns_name)
    zone_id = aws_lb.seunghyeon-lb.zone_id
  }
}

# Create EFS
data "aws_efs_file_system" "hugo" {}
resource "aws_efs_mount_target" "hugo-mount" {
  file_system_id = data.aws_efs_file_system.hugo.file_system_id
  subnet_id = module.vpc.private_subnets.0
  ip_address = "10.0.1.181"
  security_groups = [aws_security_group.seunghyeon-ec2.id]
}

