# ########################## ALB - Public ##########################
module "alb_public" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.3.1"

  name = "mbition"

  load_balancer_type = "application"

  vpc_id          = module.vpc.vpc_id
  subnets         = flatten([module.vpc.public_subnets])
  security_groups = flatten([aws_security_group.alb_public.id])

  enable_deletion_protection = true

  # access_logs = {
  #   bucket = "${var.s3_prefix}--alb-mb-access-logs"
  # }
  # depends_on = [module.s3_alb_logs]

  ################### Listeners ##################
  # https_listeners = [
  #   {
  #     port            = 443
  #     protocol        = "HTTPS"
  #     ssl_policy      = "ELBSecurityPolicy-TLS-1-2-2017-01"
  #     certificate_arn = data.terraform_remote_state.management.outputs.acm_certificate_arn
  #     action_type     = "fixed-response"
  #     fixed_response = {
  #       content_type = "text/plain"
  #       status_code  = 404
  #     }
  #   }
  # ]

  http_tcp_listeners = [
    {
      port        = 80
      protocol    = "HTTP"
      action_type = "redirect"
      redirect = {
        port        = "443"
        protocol    = "HTTP"
        status_code = "HTTP_301"
      }
    }
  ]

  ################## Target Groups ##################
  target_groups = [
    {
      name             = "mb"
      backend_protocol = "HTTP"
      backend_port     = 8080 # change according to application port
      target_type      = "ip"
      health_check = {
        enabled             = true
        interval            = 15
        protocol            = "HTTP"
        path                = "/health"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 5
        matcher             = 200
      }
    }
  ]

#   ################## Listener Rules ##################
#   https_listener_rules = [
#     {
#       https_listener_index = 0

#       actions = [
#         {
#           type               = "forward"
#           target_group_index = 0
#         }
#       ]

#       conditions = [{
#         host_headers = ["mb"]
#       }]
#     }
#   ]
}


########################## ALB mb Security Group ##########################
resource "aws_security_group" "alb_public" {
  name        = "alb-mb"
  vpc_id      = module.vpc.vpc_id
  description = "Managed by Terraform - ALB mb security group"
}

# # Ingress
# resource "aws_security_group_rule" "alb-public-allow-http" {
#   type              = "ingress"
#   from_port         = 80
#   to_port           = 80
#   protocol          = "tcp"
#   prefix_list_ids   = [data.aws_ec2_managed_prefix_list.cdn-ips.id]
#   security_group_id = aws_security_group.alb_public.id
#   description       = "Managed by Terraform - Allow all traffic"
# }

# Egress
resource "aws_security_group_rule" "alb-public-allow-all-out" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_public.id
  description       = "Managed by Terraform - Allow all egress traffic"
}
