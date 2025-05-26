data "aws_ami" "al2023" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-2.0.*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

locals {
  # demonstrating pulling from secretsmanager
  # should use readonly creds instead of using admin creds to access the db but used here for demo purposes
  secretsmanager_mysql_creds = jsondecode(aws_secretsmanager_secret_version.rds.secret_string)
  mysql = {
    host    = lookup(local.secretsmanager_mysql_creds, "host")
    port    = lookup(local.secretsmanager_mysql_creds, "port")
    user    = lookup(local.secretsmanager_mysql_creds, "username")
    pass    = lookup(local.secretsmanager_mysql_creds, "password")
    db      = lookup(local.secretsmanager_mysql_creds, "db_name")
    timeout = lookup(local.secretsmanager_mysql_creds, "timeout")
  }

  cloud_init = base64encode(<<-CLOUD_INIT
    #cloud-config
    package_update: true
    packages:
      - socat
      - mysql

    runcmd:
      - amazon-linux-extras enable nginx1
      - yum clean metadata
      - yum install -y nginx

      - echo 'export MYSQL_HOST="${local.mysql.host}"' >> /etc/profile.d/app_env.sh
      - echo 'export MYSQL_PORT="${local.mysql.port}"' >> /etc/profile.d/app_env.sh
      - echo 'export MYSQL_USER="${local.mysql.user}"' >> /etc/profile.d/app_env.sh
      - echo 'export MYSQL_PASS="${local.mysql.pass}"' >> /etc/profile.d/app_env.sh
      - echo 'export MYSQL_DB="${local.mysql.db}"' >> /etc/profile.d/app_env.sh
      - echo 'export MYSQL_TIMEOUT="${local.mysql.timeout}"' >> /etc/profile.d/app_env.sh

      - |
        cat > /usr/local/bin/app1_handler.sh <<'EOF'
        #!/bin/bash
        source /etc/profile.d/app_env.sh
        if mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" -e "SELECT 1;" --init-command="SET SESSION wait_timeout=$MYSQL_TIMEOUT" &>/dev/null; then
          printf "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nApp 1: MySQL OK"
        else
          printf "HTTP/1.1 503 Service Unavailable\r\nContent-Type: text/plain\r\n\r\nApp 1: MySQL ERROR"
        fi
        EOF

      - |
        cat > /usr/local/bin/app2_handler.sh <<'EOF'
        #!/bin/bash
        source /etc/profile.d/app_env.sh
        if mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" -e "SELECT 1;" --init-command="SET SESSION wait_timeout=$MYSQL_TIMEOUT" &>/dev/null; then
          printf "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nApp 2: MySQL OK"
        else
          printf "HTTP/1.1 503 Service Unavailable\r\nContent-Type: text/plain\r\n\r\nApp 2: MySQL ERROR"
        fi
        EOF

      - |
        cat > /usr/local/bin/app1.sh <<'EOF'
        #!/bin/bash
        socat TCP-LISTEN:8081,reuseaddr,fork EXEC:"/usr/local/bin/app1_handler.sh"
        EOF

      - |
        cat > /usr/local/bin/app2.sh <<'EOF'
        #!/bin/bash
        socat TCP-LISTEN:8082,reuseaddr,fork EXEC:"/usr/local/bin/app2_handler.sh"
        EOF

      - chmod +x /usr/local/bin/app1_handler.sh /usr/local/bin/app2_handler.sh
      - chmod +x /usr/local/bin/app1.sh /usr/local/bin/app2.sh
      - nohup /usr/local/bin/app1.sh > /var/log/app1.log 2>&1 &
      - nohup /usr/local/bin/app2.sh > /var/log/app2.log 2>&1 &

      - |
        cat > /etc/nginx/nginx.conf <<'EOF'
        user nginx;
        worker_processes auto;
        error_log /var/log/nginx/error.log;
        pid /run/nginx.pid;

        events {
          worker_connections 1024;
        }

        http {
          include       /etc/nginx/mime.types;
          default_type  text/plain;
          keepalive_timeout  60;

          server {
            listen 0.0.0.0:80;

            location /app1 {
              proxy_pass http://localhost:8081;
            }

            location /app2 {
              proxy_pass http://localhost:8082;
            }

            location / {
              return 200 "Health: OK: MaD GrEEtz! #End2EndBurner";
            }
          }
        }
        EOF
      - systemctl enable nginx
      - systemctl restart nginx
  CLOUD_INIT
  )
}

locals {
  launch_template_name_prefix = format("%s-%s", var.env_prefix, "web-")
}

resource "aws_launch_template" "web_lt" {
  name_prefix            = local.launch_template_name_prefix
  image_id               = data.aws_ami.al2023.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  user_data              = local.cloud_init

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = format("%s-%s", var.env_prefix, "web-instance")
    }
  }
}

locals {
  web_asg_name          = format("%s-%s", var.env_prefix, "web-asg")
  web_asg_instance_name = format("%s-%s", var.env_prefix, "web-instance")
}

resource "aws_autoscaling_group" "web_asg" {
  name             = local.web_asg_name
  min_size         = 2
  max_size         = 8
  desired_capacity = 2
  vpc_zone_identifier = [
    lookup(lookup(module.vpcs, local.vpc_names.app).private_subnet_name_to_subnet_id, "proxy1"),
    lookup(lookup(module.vpcs, local.vpc_names.app).private_subnet_name_to_subnet_id, "proxy2")
  ]
  target_group_arns         = [aws_lb_target_group.tg.arn]
  health_check_type         = "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }

  # This tells the asg to keep 100% of your desired capacity healthy before it starts terminating old instances,
  # and allows it to exceed capacity by up to 50% during replacements.
  # This coincides with terraform_data.asg_instance_refresher to get 'launch before terminate' behavior.
  instance_maintenance_policy {
    min_healthy_percentage = 100
    max_healthy_percentage = 150
  }

  tag {
    key                 = "Name"
    value               = local.web_asg_instance_name
    propagate_at_launch = true
  }

  # will launch with initial desired_capacity value
  # but need to ignore future values to let cloudwatch control scaling out and in
  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

### ASG Instance refresher launch before terminate
locals {
  asg_instance_refresher = { for this in [var.asg_instance_refresher] : this => this if var.asg_instance_refresher }
}

resource "terraform_data" "asg_instance_refresher" {
  for_each = local.asg_instance_refresher

  # trigger on launch template user_data or image_id changes
  # using sha1 for unique string
  triggers_replace = [
    sha1(aws_launch_template.web_lt.user_data),
    aws_launch_template.web_lt.image_id
  ]

  # Automatically uses latest launch template version.
  # Must wait until it finishes before starting a new one (10min+ depending on config) otherwise the command will error.
  # An error occurred (InstanceRefreshInProgress) when calling the StartInstanceRefresh operation: An Instance Refresh is already in progress and blocks the execution of this Instance Refresh.
  # Dont run instance refresh command on first version of the launch template (unnecessary) but will run on subsequent changes to user_data in the launch template.
  # MinHealthyPercentage = 100 ensures new instances are brought up before any old ones are taken down
  provisioner "local-exec" {
    command = <<-EOT
      # fetch the LT’s latest version number
      VERSION=$(aws ec2 describe-launch-templates \
        --launch-template-ids ${aws_launch_template.web_lt.id} \
        --query 'LaunchTemplates[0].LatestVersionNumber' --output text \
        --region ${local.region})

      if [ "$VERSION" != "1" ]; then
        aws autoscaling start-instance-refresh \
          --auto-scaling-group-name ${aws_autoscaling_group.web_asg.name} \
          --preferences '${jsonencode({ InstanceWarmup = 300, MinHealthyPercentage = 100 })}' \
          --region ${local.region}
      fi
    EOT
  }
}

### CoudWatch Alarms for Scaling in and out
# scale out based on cpu
locals {
  asg_policy_scale_out_name      = format("%s-%s", var.env_prefix, "scale-out")
  asg_policy_scale_in_name       = format("%s-%s", var.env_prefix, "scale-in")
  cloudwatch_alarm_cpu_high_name = format("%s-%s", var.env_prefix, "cpu-high")
  cloudwatch_alarm_cpu_low_name  = format("%s-%s", var.env_prefix, "cpu-low")
}

resource "aws_autoscaling_policy" "scale_out" {
  name                   = local.asg_policy_scale_out_name
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = local.cloudwatch_alarm_cpu_high_name
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Scale out if CPU > 70% for 2 minutes"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_out.arn]
}

# scale in based on cpu
resource "aws_autoscaling_policy" "scale_in" {
  name                   = local.asg_policy_scale_in_name
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = local.cloudwatch_alarm_cpu_low_name
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 30
  alarm_description   = "Scale in if CPU < 30% for 2 minutes"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_in.arn]
}

