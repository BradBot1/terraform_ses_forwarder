#  Copyright 2025 BradBot_1

#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at

#      http://www.apache.org/licenses/LICENSE-2.0

#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
resource "random_string" "uid" {
  length  = 16
  special = false
  upper   = false
  lower   = true
  numeric = true
}

resource "aws_s3_bucket" "email_store" {
  depends_on    = [random_string.uid]
  bucket        = "${lower(var.service_prefix)}-${random_string.uid.result}"
  force_destroy = true
  tags = {
    Name    = "Email Forwading Storage"
    Service = var.service_tag_value
  }
}

resource "aws_s3_bucket_policy" "email_store" {
  depends_on = [aws_s3_bucket.email_store]
  bucket     = aws_s3_bucket.email_store.id
  policy     = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowSESPuts",
            "Effect": "Allow",
            "Principal": {
                "Service": "ses.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::${aws_s3_bucket.email_store.id}/*",
            "Condition": {
                "StringEquals": {
                    "aws:Referer": "${data.aws_caller_identity.current.account_id}"
                }
            }
        }
    ]
}
EOF
}

data "archive_file" "email_forwarder" {
  type = "zip"
  source_content = templatefile("${path.module}/lambda_function.py.tftpl", {
    from   = var.from_address
    to     = var.to_address
    region = var.region
    bucket = aws_s3_bucket.email_store.id
  })
  source_content_filename = "lambda_function.py"
  output_path             = "${path.module}/lambda_function.zip"
}

resource "aws_iam_policy" "email_forwarder" {
  depends_on = [random_string.uid]
  name       = "${var.upper_service_prefix}-${random_string.uid.result}"
  policy     = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Action": [
				"logs:CreateLogGroup",
				"logs:CreateLogStream",
				"logs:PutLogEvents"
			],
			"Resource": "arn:aws:logs:*:*:*"
		},
		{
			"Effect": "Allow",
			"Action": "ses:SendRawEmail",
			"Resource": "*"
		},
		{
			"Effect": "Allow",
			"Action": [
				"s3:GetObject",
				"s3:PutObject"
			],
			"Resource": "arn:aws:s3:::*"
		}
	]
}
EOF
  tags = {
    Name    = "Email Forwading Lambda Policy"
    Service = var.service_tag_value
  }
}

resource "aws_iam_role" "email_forwarder" {
  depends_on         = [random_string.uid]
  name               = "${var.upper_service_prefix}AssumeRole-${random_string.uid.result}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
  tags = {
    Name    = "Email Forwading Lambda Role"
    Service = var.service_tag_value
  }
}

resource "aws_iam_role_policy_attachment" "email_forwarder" {
  depends_on = [aws_iam_role.email_forwarder, aws_iam_policy.email_forwarder]
  role       = aws_iam_role.email_forwarder.name
  policy_arn = aws_iam_policy.email_forwarder.arn
}

resource "aws_lambda_function" "email_forwarder" {
  depends_on       = [random_string.uid, data.archive_file.email_forwarder, aws_iam_role_policy_attachment.email_forwarder, aws_ses_email_identity.from_address]
  function_name    = "${var.upper_service_prefix}-${random_string.uid.result}"
  role             = aws_iam_role.email_forwarder.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.13"
  filename         = data.archive_file.email_forwarder.output_path
  source_code_hash = data.archive_file.email_forwarder.output_base64sha256
  timeout          = 30
  tags = {
    Name    = "Email Forwading Lambda"
    Service = var.service_tag_value
  }
}

resource "aws_cloudwatch_log_group" "email_forwarder" {
  depends_on        = [aws_lambda_function.email_forwarder]
  name              = "/aws/lambda/${aws_lambda_function.email_forwarder.function_name}"
  retention_in_days = 7
  tags = {
    Name    = "Email Forwading Logs"
    Service = var.service_tag_value
  }
}

resource "aws_ses_email_identity" "from_address" {
  email = var.from_address
}

resource "aws_ses_receipt_rule_set" "trigger" {
  depends_on    = [aws_ses_email_identity.from_address]
  rule_set_name = "${var.upper_service_prefix}-${random_string.uid.result}"
}

resource "aws_ses_receipt_rule" "trigger" {
  depends_on = [random_string.uid, aws_ses_receipt_rule_set.trigger, aws_lambda_function.email_forwarder, aws_s3_bucket.email_store]
  name       = "${var.upper_service_prefix}-${random_string.uid.result}"
  # as said by https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ses_receipt_rule_set.html
  recipients    = var.forwarding_filters
  rule_set_name = aws_ses_receipt_rule_set.trigger.id
  enabled       = true
  tls_policy    = "Require"
  scan_enabled  = true
  s3_action {
    bucket_name = aws_s3_bucket.email_store.id
    position    = 1
  }
  lambda_action {
    function_arn    = aws_lambda_function.email_forwarder.arn
    invocation_type = "Event"
    position        = 2
  }
  stop_action {
    scope    = "RuleSet"
    position = 3
  }
}

resource "aws_lambda_permission" "trigger" {
  statement_id   = "AllowExecutionFromSES"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.email_forwarder.function_name
  source_account = data.aws_caller_identity.current.account_id
  principal      = "ses.amazonaws.com"
}

resource "aws_ses_active_receipt_rule_set" "trigger" {
  depends_on    = [aws_ses_receipt_rule.trigger]
  rule_set_name = aws_ses_receipt_rule_set.trigger.id
}
