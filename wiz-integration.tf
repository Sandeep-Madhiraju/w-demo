data "aws_caller_identity" "current" {}

resource "aws_iam_role" "wiz_integration_role" {
  name = "WizIntegrationRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        AWS = "arn:aws:iam::<WIZ_ACCOUNT_ID>:root"
      },
      Action = "sts:AssumeRole",
      Condition = {
        StringEquals = {
          "sts:ExternalId" = "<WIZ_EXTERNAL_ID>"
        }
      }
    }]
  })
}

resource "aws_iam_policy" "wiz_read_only_policy" {
  name        = "WizReadOnlyAccess"
  description = "Read-only access for Wiz CSPM integration"

  policy = file("${path.module}/wiz-policy.json")
}

resource "aws_iam_role_policy_attachment" "wiz_attach_policy" {
  role       = aws_iam_role.wiz_integration_role.name
  policy_arn = aws_iam_policy.wiz_read_only_policy.arn
}
