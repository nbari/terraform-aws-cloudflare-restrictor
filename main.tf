data "archive_file" "cloudflare-restrictor" {
  type        = "zip"
  source_file = "${path.module}/lambda/cloudflare_restrictor.py"
  output_path = "${path.module}/dist/cloudflare_restrictor.zip"
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cloudflare-restrictor" {
  name_prefix        = "cloudflare-restrictor-"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.cloudflare-restrictor.name
}

data "aws_iam_policy_document" "cloudflare-restrictor" {
  statement {
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/${var.tag_key}"
      values   = [var.tag_value]
    }
  }

  statement {
    actions   = ["ec2:DescribeSecurityGroups"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cloudflare-restrictor" {
  name_prefix = "cloudflare-restrictor-"
  policy      = data.aws_iam_policy_document.cloudflare-restrictor.json
}

resource "aws_iam_role_policy_attachment" "cloudflare-restrictor" {
  policy_arn = aws_iam_policy.cloudflare-restrictor.arn
  role       = aws_iam_role.cloudflare-restrictor.name
}

resource "aws_lambda_function" "cloudflare-restrictor" {
  filename         = data.archive_file.cloudflare-restrictor.output_path
  function_name    = "cloudflare_restrictor"
  handler          = "cloudflare_restrictor.lambda_handler"
  role             = aws_iam_role.cloudflare-restrictor.arn
  runtime          = "python3.11"
  source_code_hash = filebase64sha256(data.archive_file.cloudflare-restrictor.output_path)
  timeout          = 180
  description      = "Restrict Cloudflare IPs to security groups"
  environment {
    variables = {
      PORTS_LIST = join(",", var.allowed_ports)
      TAG_KEY    = var.tag_key
      TAG_VALUE  = var.tag_value
    }
  }

  lifecycle {
    ignore_changes = [
      filename,
      last_modified,
    ]
  }
}

resource "aws_cloudwatch_event_rule" "cloudflare-restrictor" {
  name_prefix         = "cloudflare_restrictor-scheduled-rule-"
  schedule_expression = var.execution_expression

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_event_target" "cloudflare-restrictor" {
  arn  = aws_lambda_function.cloudflare-restrictor.arn
  rule = aws_cloudwatch_event_rule.cloudflare-restrictor.name

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lambda_permission" "cloudflare-restrictor" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cloudflare-restrictor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cloudflare-restrictor.arn

  lifecycle {
    create_before_destroy = true
  }
}
