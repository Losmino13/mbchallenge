################## Cluster ##################
module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "4.1.3"

  cluster_name = "mbition"
  cluster_settings = {
    "name" : "containerInsights",
    "value" : "enabled"
  }
  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 100
      }
    }
  }
}
################## ECS Cloudwatch Log Group ##################
resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/mb"
  retention_in_days = "14"
}
########################## ECS mb ##########################
locals {
  mb_app_port = 8080
  mb_cpu      = 512
  mb_memory   = 1024
}

resource "aws_ecs_task_definition" "mb" {
  family                   = "mbition-task"
  container_definitions    = <<EOF
[
    {
    "requiresCompatibilities": [
        "FARGATE"
    ],
    "family": "",
    "containerDefinitions": [
        {
            "name": "mbition",
            "image": "registry.hub.docker.com/library/losmino13/mbition",
            "essential": true
        }
    ],
    "volumes": [],
    "networkMode": "awsvpc",
    "memory": 1024,
    "cpu": 512,
    "executionRoleArn": ""
    }
]
EOF
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = local.mb_cpu
  memory                   = local.mb_memory
  execution_role_arn       = aws_iam_role.mb-task-execution-role.arn
  task_role_arn            = aws_iam_role.mb-task-role.arn
}

data "aws_ecs_task_definition" "mb" {
  task_definition = aws_ecs_task_definition.mb.family
  depends_on      = [aws_ecs_task_definition.mb]
}

resource "aws_ecs_service" "mb" {
  name    = "mb"
  cluster = module.ecs.cluster_id

  task_definition = "${aws_ecs_task_definition.mb.family}:${max(
    aws_ecs_task_definition.mb.revision,
    data.aws_ecs_task_definition.mb.revision,
  )}"

  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "LATEST"
  depends_on       = [aws_ecs_task_definition.mb, module.alb_public, resource.aws_cloudwatch_log_group.ecs_log_group]

  load_balancer {
    target_group_arn = module.alb_public.target_group_arns[0]
    container_name   = "mb"
    container_port   = local.mb_app_port
  }

  #   service_registries {
  #     container_name = "mb"
  #     registry_arn   = aws_service_discovery_service.mb.arn
  #   }

  network_configuration {
    subnets          = flatten([module.vpc.private_subnets])
    security_groups  = [aws_security_group.mb-ecs.id]
    assign_public_ip = false
  }

  lifecycle {
    create_before_destroy = false
    ignore_changes        = [task_definition]
  }

}

data "template_file" "mb" {
  template = file("files/task-definitions/task.json")
}

# ######################### Service Discovery ##########################
# resource "aws_service_discovery_service" "mb" {
#   name = "mb"

#   dns_config {
#     namespace_id = aws_service_discovery_private_dns_namespace.sd.id

#     dns_records {
#       ttl  = 10
#       type = "A"
#     }

#     routing_policy = "MULTIVALUE"
#   }

#   health_check_custom_config {
#     failure_threshold = 1
#   }
# }

########################### ECS SG ##########################
resource "aws_security_group" "mb-ecs" {
  name        = "mb-ecs"
  vpc_id      = module.vpc.vpc_id
  description = "Managed by Terraform - Security Group for the ECS"

  ingress {
    protocol    = "tcp"
    from_port   = local.mb_app_port
    to_port     = local.mb_app_port
    cidr_blocks = flatten([var.public_subnets, var.private_subnets])
    description = "Managed by Terraform - Allow public and private subnets"
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
    description = "Managed by Terraform - Allow all egress traffic"
  }
}

########################### Task Execution Role ##########################
data "aws_iam_policy_document" "mb-task-execution-role" {
  statement {
    sid     = "FargateAssumeRolePolicy"
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type = "Service"

      identifiers = [
        "ecs.amazonaws.com",
        "ecs-tasks.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_role" "mb-task-execution-role" {
  name                  = "mb-task-execution-role"
  description           = "Managed by Terraform - Task Execution Role"
  path                  = "/"
  force_detach_policies = true
  assume_role_policy    = data.aws_iam_policy_document.mb-task-execution-role.json
}

########################## Task Role ##########################
data "aws_iam_policy_document" "mb-task-role" {
  statement {
    sid     = "CloudWatchLogPolicy"
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type = "Service"

      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "mb-task-role" {
  name                  = "mb-task-role"
  description           = "Managed by Terraform - Task Role"
  path                  = "/"
  force_detach_policies = true
  assume_role_policy    = data.aws_iam_policy_document.mb-task-role.json
}

########################### Allow Cloudwatch Logs ##########################

data "aws_iam_policy_document" "mb-logs" {
  statement {
    sid    = "CloudWatchLogPolicy"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:CreateExportTask",
      "logs:CreateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:GetLogDelivery",
      "logs:ListLogDeliveries",
      "logs:UpdateLogDelivery"
    ]
    resources = [
      "${aws_cloudwatch_log_group.ecs_log_group.arn}:*",
      "${aws_cloudwatch_log_group.ecs_log_group.arn}"
    ]
  }
}

resource "aws_iam_policy" "mb-logs" {
  name        = "mb-cloudwatch-logs"
  description = "Managed by Terraform - CloudWatch Logs Policy"
  path        = "/"
  policy      = data.aws_iam_policy_document.mb-logs.json
}

resource "aws_iam_policy_attachment" "mb-logs" {
  name       = "mb-cloudwatch-logs"
  roles      = [aws_iam_role.mb-task-execution-role.name]
  policy_arn = aws_iam_policy.mb-logs.arn
}
