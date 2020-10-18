# Upload Keypair
resource "aws_key_pair" "seunghyeon-bastion" {
  key_name = "seunghyeon-bastion"
  public_key = file("/home/sin/.ssh/project/seunghyeon-bastion.pub")
}
resource "aws_key_pair" "seunghyeon-ec2" {
  key_name = "seunghyeon-ec2"
  public_key = file("/home/sin/.ssh/project/seunghyeon-ec2.pub")
}

# Create IAM Role
## MediaConvert IAM Role
resource "aws_iam_role" "seunghyeon-mediaconvert" {
  name = "seunghyeon-mediaconvert"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "mediaconvert.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}
### Attach Policy for MediaConvert IAM Role
resource "aws_iam_role_policy_attachment" "AmazonS3FullAccess" {
  role       = aws_iam_role.seunghyeon-mediaconvert.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
resource "aws_iam_role_policy_attachment" "AmazonAPIGatewayInvokeFullAccess" {
  role       = aws_iam_role.seunghyeon-mediaconvert.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonAPIGatewayInvokeFullAccess"
}
## Lambda IAM Role
resource "aws_iam_role" "seunghyeon-lambda" {
  name = "seunghyeon-lambda"
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
}
### Attach Policy for Lambda IAM Role
resource "aws_iam_role_policy_attachment" "AWSLambdaBasicExecutionRole" {
  role = aws_iam_role.seunghyeon-lambda.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy_attachment" "AWSLambdaFullAccess" {
  role = aws_iam_role.seunghyeon-lambda.id
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaFullAccess"
}
resource "aws_iam_role_policy_attachment" "AmazonS3FullAccess2" {
  role       = aws_iam_role.seunghyeon-lambda.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
resource "aws_iam_role_policy" "customizing" {
  role = aws_iam_role.seunghyeon-lambda.id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*",
            "Effect": "Allow",
            "Sid": "Logging"
        },
        {
            "Action": [
                "iam:PassRole"
            ],
            "Resource": [
                "${aws_iam_role.seunghyeon-mediaconvert.arn}"
            ],
            "Effect": "Allow",
            "Sid": "PassRole"
        },
        {
            "Action": [
                "mediaconvert:*"
            ],
            "Resource": [
                "*"
            ],
            "Effect": "Allow",
            "Sid": "MediaConvertService"
        },
        {
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "*"
            ],
            "Effect": "Allow",
            "Sid": "S3Service"
        }
    ]
}
EOF
}

# Set Lambda
resource "aws_lambda_function" "mediaconvert" {
  function_name = "seunghyeon-testing"
  handler = "convert.handler"
  filename = "VODLambdaConvert.zip"
  role = aws_iam_role.seunghyeon-lambda.arn
  runtime = "python3.8"

  # Set Enviroment
  environment {
    variables = {
      "DestinationBucket" = aws_s3_bucket.transcoded.id,
      "MediaConvertRole" = aws_iam_role.seunghyeon-mediaconvert.arn
      "Application" = "VOD"
    }
  }
}
## Permisson for Bucket to Trigger
resource "aws_lambda_permission" "function_permission" {
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mediaconvert.function_name
  principal = "s3.amazonaws.com"
  source_arn = aws_s3_bucket.original.arn
}
## Bucket Triggering
resource "aws_s3_bucket_notification" "original-bucket-trigger" {
  bucket = aws_s3_bucket.original.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.mediaconvert.arn
    events = [
      "s3:ObjectCreated:Put"]
  }
}

# Create Original S3
resource "aws_s3_bucket" "original" {
  bucket = "seunghyeon-project-original"
  acl = "private"

  versioning {
    enabled = true
  }
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }

  website {
    index_document = "index.html"
  }
}
resource "aws_s3_bucket_policy" "b" {
  bucket = aws_s3_bucket.original.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AddPerm",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": [
              "arn:aws:s3:::${aws_s3_bucket.original.id}/*"
              ]
        }
    ]
}
EOF
}
# Create transcoded S3
resource "aws_s3_bucket" "transcoded" {
  bucket = "seunghyeon-project-transcoded"
  acl = "private"

  versioning {
    enabled = true
  }
}
resource "aws_s3_bucket_policy" "c" {
  bucket = aws_s3_bucket.transcoded.id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AddPerm",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": [
              "arn:aws:s3:::${aws_s3_bucket.transcoded.id}/*"
              ]
        }
    ]
}
EOF
}
//# Upload 'test.mp4' to Original Bucket
//resource "aws_s3_bucket_object" "test" {
//  bucket = aws_s3_bucket.original.id
//  key = "test.mp4"
//  source = "test.mp4"
//  depends_on = [aws_s3_bucket_notification.original-bucket-trigger]
//}

# Create SNS Module
module "admin-sns-email-topic" {
  source = "github.com/deanwilson/tf_sns_email"

  display_name  = "seunghyeon-sns-test"
  email_address = "zzlinmer92@gmail.com"
  owner         = "Example.org:Admin"
  stack_name    = "seunghyeon-sns"
}
## Cloudwatch Setting
resource "aws_cloudwatch_event_rule" "seunghyeon-watch" {
  name          = "seunghyeon-cloudwatch-test"
  event_pattern = <<EOF
  {
"source": [
    "aws.mediaconvert"
],
"detail-type": [
    "MediaConvert Job State Change"
],
"detail": {
    "status": [
    "COMPLETE",
    "ERROR"
    ],
"userMetadata": {
    "application": [
        "VOD"
    ]
    }
}
}
EOF
}
## Target Setting
resource "aws_cloudwatch_event_target" "seunghyeon-sns" {
  ### Use Module's output to Use Target arn
  arn  = module.admin-sns-email-topic.arn
  rule = aws_cloudwatch_event_rule.seunghyeon-watch.name

  input_transformer {
    input_paths    = {"jobId":"$.detail.jobId","settings":"$.detail.userMetadata.input","application":"$.detail.userMetadata.application","status":"$.detail.status"}
    input_template = "\"Job <jobId> finished with status <status>. Job details: https://ap-northeast-2.console.aws.amazon.com/mediaconvert/home?region=ap-northeast-2#/jobs/summary/<jobId>\""
  }
  depends_on = [module.admin-sns-email-topic]
}
