#!/bin/bash

# AWS Lambda Deployment Script
# Deploys the auto-scaling Lambda function to AWS

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   AWS Lambda Auto-Scaling Deployment                             ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════╝${NC}\n"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗ AWS CLI not installed${NC}"
    echo "Install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

echo -e "${GREEN}✓ AWS CLI found${NC}\n"

# Configuration
FUNCTION_NAME="ai-incident-autoscaler"
REGION="${AWS_REGION:-us-east-1}"
RUNTIME="python3.11"
TIMEOUT=30
MEMORY=256

echo -e "${YELLOW}Configuration:${NC}"
echo "  Function Name: $FUNCTION_NAME"
echo "  Region: $REGION"
echo "  Runtime: $RUNTIME"
echo ""

# Get configuration from user
read -p "Enter your Auto Scaling Group name: " ASG_NAME
read -p "Enter minimum capacity (default: 2): " MIN_CAP
read -p "Enter maximum capacity (default: 10): " MAX_CAP

MIN_CAP=${MIN_CAP:-2}
MAX_CAP=${MAX_CAP:-10}

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Step 1: Creating IAM Role${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Create IAM role trust policy
cat > /tmp/trust-policy.json <<EOF
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

# Create IAM role
ROLE_NAME="${FUNCTION_NAME}-role"

if aws iam get-role --role-name "$ROLE_NAME" --region "$REGION" 2>/dev/null; then
    echo -e "${YELLOW}⚠ Role already exists, using existing role${NC}"
    ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --region "$REGION" --query 'Role.Arn' --output text)
else
    echo "Creating IAM role..."
    ROLE_ARN=$(aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document file:///tmp/trust-policy.json \
        --region "$REGION" \
        --query 'Role.Arn' \
        --output text)
    
    echo -e "${GREEN}✓ Role created: $ROLE_ARN${NC}"
fi

# Create IAM policy for auto-scaling
cat > /tmp/lambda-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:SetDesiredCapacity",
        "autoscaling:UpdateAutoScalingGroup",
        "ec2:DescribeInstances",
        "cloudwatch:PutMetricData",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF

POLICY_NAME="${FUNCTION_NAME}-policy"

if aws iam get-policy --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$POLICY_NAME" 2>/dev/null; then
    echo -e "${YELLOW}⚠ Policy already exists${NC}"
else
    echo "Creating IAM policy..."
    aws iam create-policy \
        --policy-name "$POLICY_NAME" \
        --policy-document file:///tmp/lambda-policy.json \
        --region "$REGION" > /dev/null
    
    echo -e "${GREEN}✓ Policy created${NC}"
fi

# Attach policy to role
echo "Attaching policy to role..."
aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$POLICY_NAME" \
    --region "$REGION"

echo -e "${GREEN}✓ Policy attached${NC}\n"

# Wait for IAM role to propagate
echo "Waiting for IAM role to propagate (10 seconds)..."
sleep 10

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Step 2: Packaging Lambda Function${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Create deployment package
DEPLOY_DIR="/tmp/lambda-deploy"
rm -rf "$DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"

echo "Copying Lambda function..."
cp autoscale_handler.py "$DEPLOY_DIR/lambda_function.py"

# Install dependencies (boto3 is included in Lambda runtime, but we include it anyway)
if [ -f requirements.txt ]; then
    echo "Installing dependencies..."
    pip install -r requirements.txt -t "$DEPLOY_DIR" --quiet
fi

# Create ZIP package
echo "Creating deployment package..."
cd "$DEPLOY_DIR"
zip -r9 /tmp/lambda-function.zip . > /dev/null
cd - > /dev/null

echo -e "${GREEN}✓ Package created: /tmp/lambda-function.zip${NC}\n"

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Step 3: Deploying to AWS Lambda${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Check if function exists
if aws lambda get-function --function-name "$FUNCTION_NAME" --region "$REGION" 2>/dev/null; then
    echo "Function exists, updating..."
    
    aws lambda update-function-code \
        --function-name "$FUNCTION_NAME" \
        --zip-file fileb:///tmp/lambda-function.zip \
        --region "$REGION" > /dev/null
    
    aws lambda update-function-configuration \
        --function-name "$FUNCTION_NAME" \
        --environment "Variables={AUTO_SCALING_GROUP_NAME=$ASG_NAME,MIN_CAPACITY=$MIN_CAP,MAX_CAPACITY=$MAX_CAP,SCALE_UP_INCREMENT=2,SCALE_DOWN_INCREMENT=1}" \
        --region "$REGION" > /dev/null
    
    echo -e "${GREEN}✓ Function updated${NC}"
else
    echo "Creating new function..."
    
    aws lambda create-function \
        --function-name "$FUNCTION_NAME" \
        --runtime "$RUNTIME" \
        --role "$ROLE_ARN" \
        --handler "lambda_function.lambda_handler" \
        --zip-file fileb:///tmp/lambda-function.zip \
        --timeout "$TIMEOUT" \
        --memory-size "$MEMORY" \
        --environment "Variables={AUTO_SCALING_GROUP_NAME=$ASG_NAME,MIN_CAPACITY=$MIN_CAP,MAX_CAPACITY=$MAX_CAP,SCALE_UP_INCREMENT=2,SCALE_DOWN_INCREMENT=1}" \
        --region "$REGION" > /dev/null
    
    echo -e "${GREEN}✓ Function created${NC}"
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Step 4: Creating Function URL${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Create or update function URL
if aws lambda get-function-url-config --function-name "$FUNCTION_NAME" --region "$REGION" 2>/dev/null; then
    echo -e "${YELLOW}⚠ Function URL already exists${NC}"
    FUNCTION_URL=$(aws lambda get-function-url-config --function-name "$FUNCTION_NAME" --region "$REGION" --query 'FunctionUrl' --output text)
else
    echo "Creating Function URL..."
    FUNCTION_URL=$(aws lambda create-function-url-config \
        --function-name "$FUNCTION_NAME" \
        --auth-type NONE \
        --region "$REGION" \
        --query 'FunctionUrl' \
        --output text)
    
    # Add permission for public access
    aws lambda add-permission \
        --function-name "$FUNCTION_NAME" \
        --statement-id FunctionURLAllowPublicAccess \
        --action lambda:InvokeFunctionUrl \
        --principal "*" \
        --function-url-auth-type NONE \
        --region "$REGION" 2>/dev/null || true
    
    echo -e "${GREEN}✓ Function URL created${NC}"
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✓ Deployment Complete!                                         ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${BLUE}Function Details:${NC}"
echo "  Name: $FUNCTION_NAME"
echo "  Region: $REGION"
echo "  ASG: $ASG_NAME"
echo "  Capacity: $MIN_CAP - $MAX_CAP instances"
echo ""
echo -e "${BLUE}Function URL:${NC}"
echo -e "  ${GREEN}$FUNCTION_URL${NC}"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Next Steps:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
echo "1. Add this URL to your .env file:"
echo -e "   ${CYAN}AWS_LAMBDA_URL=$FUNCTION_URL${NC}"
echo ""
echo "2. Update your n8n workflow:"
echo "   - Open n8n: http://localhost:5678"
echo "   - Edit 'Trigger Auto-Scaling' node"
echo "   - Replace mock URL with Lambda URL"
echo ""
echo "3. Test the function:"
echo -e "   ${CYAN}./test-lambda.sh${NC}"
echo ""

# Save URL to file
echo "AWS_LAMBDA_URL=$FUNCTION_URL" > lambda-url.txt
echo -e "${GREEN}✓ Lambda URL saved to: lambda-url.txt${NC}\n"

# Cleanup
rm -rf "$DEPLOY_DIR" /tmp/lambda-function.zip /tmp/trust-policy.json /tmp/lambda-policy.json