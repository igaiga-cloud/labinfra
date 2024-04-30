# CloudWatchロググループの作成
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/my-ecs-logs"
  retention_in_days = 30  # 必要に応じて変更
}

# ECSクラスタの作成
resource "aws_ecs_cluster" "cluster" {
  name = "cs-vuln-cluster"
}

#高権限のポリシーの設定
resource "aws_iam_policy" "ecs_deploy_policy" {
  name        = "ecs-deploy-policy"
  description = "Policy for ECS services to allow specific actions"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "iam:List*",
          "iam:Get*",
          "iam:PassRole",
          "iam:PutRole*",
          "ssm:*",
          "ssmmessages:*",
          "ec2:RunInstances",
          "ec2:Describe*",
          "ec2:*",
          "ecs:*",
          "ecr:*",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

#ecs_deploy_roleの定義
resource "aws_iam_role" "ecs_deploy_role" {
  name = "ecs-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

#ecs_deploy_roleにecs_deploy_policyをアタッチ
resource "aws_iam_role_policy_attachment" "ecs_deploy_attachment" {
  role       = aws_iam_role.ecs_deploy_role.name
  policy_arn = aws_iam_policy.ecs_deploy_policy.arn
}

# CloudWatch Logsへの書き込み権限を持つポリシー
resource "aws_iam_policy" "cloudwatch_logs_policy" {
  name        = "cloudwatch_logs_policy"
  description = "Allow ECS tasks to write logs to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"],
      Effect   = "Allow",
      Resource = "*"
    }]
  })
}

#cloudwatchのポリシーもecs_deploy_roleにecs_deploy_policyをアタッチ
resource "aws_iam_role_policy_attachment" "cloudwatch_logs_attachment" {
  role       = aws_iam_role.ecs_deploy_role.name
  policy_arn = aws_iam_policy.cloudwatch_logs_policy.arn
}

#攻撃で利用する高権限のインスタンスプロファイルの作成----
#ec2_admin_roleの作成
resource "aws_iam_role" "ec2_admin_role" {
  name = "ec2-admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

#高い権限のポリシー作成
resource "aws_iam_policy" "ec2_admin_policy" {
  name        = "ec2-admin-policy"
  description = "Policy that allows all actions on all resources for EC2 instances"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "*",
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

#高い権限のポリシー（ec2_admin_policy）をec2_admin_roleにアタッチ
resource "aws_iam_role_policy_attachment" "ec2_admin_policy_attachment" {
  role       = aws_iam_role.ec2_admin_role.name
  policy_arn = aws_iam_policy.ec2_admin_policy.arn
}

#ec2_admin_roleをインスタンスプロファイル"ec2-admin-profile"にアタッチ
resource "aws_iam_instance_profile" "ec2_admin_profile" {
  name = "ec2-admin-profile"
  role = aws_iam_role.ec2_admin_role.name
}


# Elastic Load Balancer (ELB) の作成
resource "aws_lb" "elb" {
  name               = "my-elb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.subnet_ids

  enable_deletion_protection = false
}

# ターゲットグループの作成
resource "aws_lb_target_group" "target_group" {
  name     = "my-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type = "ip"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
  }
}

# ロードバランサーリスナーの作成
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.elb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

# ECRの作成
resource "aws_ecr_repository" "vulnweb01" {
  name                 = "vulnweb01"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  force_delete = true
}

# Null Resourceを利用してECRへの脆弱アプリのプッシュ
resource "null_resource" "vulnweb01" {
  triggers = {
    // MD5 チェックし、トリガーにする
    file_content_md5 = md5(file("${path.module}/dockerbuild.sh"))
  }

  provisioner "local-exec" {
    // ローカルのスクリプトを呼び出す
    command = "sh ${path.module}/dockerbuild.sh"

    // スクリプト専用の環境変数
    environment = {
      AWS_REGION     = var.region
      AWS_ACCOUNT_ID = var.account_id
      REPO_URL       = aws_ecr_repository.vulnweb01.repository_url
      CONTAINER_NAME = "prex55/vuln_fshare"
    }
  }
}

# ECSタスク定義の作成
resource "aws_ecs_task_definition" "task" {
  family                   = "vuln-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_deploy_role.arn
  task_role_arn            = aws_iam_role.ecs_deploy_role.arn
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([{
    name  = "cs-vuln-container"
    image = "${aws_ecr_repository.vulnweb01.repository_url}:latest"
    portMappings = [{
      containerPort = 80
      hostPort      = 80
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "ecs"
      }
   }
  }])
}

# ECSサービスの作成
resource "aws_ecs_service" "service" {
  name            = "cs-vuln-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  launch_type     = "FARGATE"
  depends_on = [aws_lb.elb]

  network_configuration {
    subnets = var.subnet_ids
    security_groups = [var.security_group_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = "cs-vuln-container"
    container_port   = 80
  }

  desired_count = 1
}
