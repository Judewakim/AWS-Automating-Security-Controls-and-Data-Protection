# Terraform script created by Jude Wakim
# This script alerts you via email about unencrypted RDS databases and unencrypted EBS volume for EC2 instances
# Using CloudTrail, CloudWatch, S3, IAM, SNS
# Make necessary modifications 

provider "aws" {
  region = "us-west-2"  # Change to your preferred region
}

resource "aws_cloudtrail" "main" {
  name                          = "DataGuardianTrail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_bucket.bucket
  
  enable_log_file_validation    = true
  is_multi_region_trail         = true
}

resource "aws_s3_bucket" "cloudtrail_bucket" {
  bucket = "data-guardian-cloudtrail-bucket"  # Change bucket name as needed
}

resource "aws_cloudwatch_log_group" "cloudtrail_logs" {
  name = "DataGuardianCloudTrailLogs"
}

resource "aws_cloudtrail_logging" "enable_logging" {
  trail_name = aws_cloudtrail.main.name
  cloud_watch_logs_log_group_arn = aws_cloudwatch_log_group.cloudtrail_logs.arn
  cloud_watch_logs_role_arn = aws_iam_role.cloudtrail_role.arn
}

resource "aws_iam_role" "cloudtrail_role" {
  name = "CloudTrailLogsRole"

  # change policy as needed
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      }
      Effect = "Allow"
      Sid    = ""
    }]
  })
}

resource "aws_iam_policy_attachment" "cloudtrail_logs" {
  name       = "CloudTrailLogsPolicyAttachment"
  roles      = [aws_iam_role.cloudtrail_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCloudTrailRole"
}

resource "aws_iam_role" "lambda_remediation_role" {
  name = "lambda_remediation_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Effect = "Allow",
      Sid    = ""
    }]
  })
}

resource "aws_iam_policy_attachment" "lambda_remediation_policy" {
  name       = "lambda_remediation_policy"
  roles      = [aws_iam_role.lambda_remediation_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_policy_attachment" "lambda_rds_policy" {
  name       = "lambda_rds_policy"
  roles      = [aws_iam_role.lambda_remediation_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
}

resource "aws_lambda_function" "remediate_unencrypted_resources" {
  filename         = "remediate_unencrypted_resources.zip"
  function_name    = "RemediateUnencryptedResources"
  role             = aws_iam_role.lambda_remediation_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("remediate_unencrypted_resources.zip")
}



resource "aws_sns_topic" "alerts" {
  name = "DataGuardianAlerts"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "wjude852@gmail.com" 
}

resource "aws_cloudwatch_metric_alarm" "unencrypted_rds_alarm" {
  alarm_name          = "UnencryptedRDSAlarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name        = "UnencryptedDBInstances"
  namespace          = "AWS/CloudTrail"
  period             = 300
  statistic          = "Sum"
  threshold          = 1

  alarm_actions      = [aws_sns_topic.alerts.arn]

  dimensions = {
    LogGroupName = aws_cloudwatch_log_group.cloudtrail_logs.name
  }
}

resource "aws_cloudwatch_log_metric_filter" "unencrypted_rds_filter" {
  log_group_name = aws_cloudwatch_log_group.cloudtrail_logs.name
  name           = "UnencryptedRDSFilter"
  # pattern for unencrypted rds DBs  
  pattern        = "{ ($.eventSource = \"rds.amazonaws.com\") && ($.eventName = \"CreateDBInstance\") && ($.responseElements.storageEncrypted IS FALSE)}"

  metric_transformation {
    name      = "UnencryptedDBInstances"
    namespace = "AWS/CloudTrail"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "unencrypted_ebs_alarm" {
  alarm_name          = "UnencryptedEBSAlarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name        = "UnencryptedEBSVolumes"
  namespace          = "AWS/CloudTrail"
  period             = 300
  statistic          = "Sum"
  threshold          = 1

  alarm_actions      = [aws_sns_topic.alerts.arn]

  dimensions = {
    LogGroupName = aws_cloudwatch_log_group.cloudtrail_logs.name
  }
}

resource "aws_cloudwatch_log_metric_filter" "unencrypted_ebs_filter" {
  log_group_name = aws_cloudwatch_log_group.cloudtrail_logs.name
  name           = "UnencryptedEBSFilter"
  pattern        = "{ ($.eventSource = \"ec2.amazonaws.com\") && ($.eventName = \"RunInstances\") && (($.requestParameters.blockDeviceMapping.items[*].ebs.encrypted NOT EXISTS) || ($.requestParameters.blockDeviceMapping.items[*].ebs.encrypted IS FALSE)) }"

  metric_transformation {
    name      = "UnencryptedEBSVolumes"
    namespace = "AWS/CloudTrail"
    value     = "1"
  }
}

