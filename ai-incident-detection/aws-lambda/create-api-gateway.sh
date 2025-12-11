#!/bin/bash

# API Gateway Creation Script for Lambda
# This creates a public API endpoint for your Lambda function

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   AWS API Gateway Setup for Lambda                               ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════╝${NC}\n"

# Configuration
FUNCTION_NAME="ai-incident-autoscaler"
REGION="us-east-1"
API_NAME="ai-autoscaler-api"
STAGE_NAME="prod"

echo -e "${YELLOW}Configuration:${NC}"
echo "  Function Name: $FUNCTION_NAME"
echo "  Region: $REGION"
echo "  API Name: $API_NAME"
echo "  Stage: $STAGE_NAME"
echo ""

# Check if AWS CLI is configured
echo -n "Checking AWS CLI configuration... "
if aws sts get-caller-identity > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo "  Account ID: $ACCOUNT_ID"
else
    echo -e "${RED}✗${NC}"
    echo -e "${RED}Error: AWS CLI not configured${NC}"
    echo "Run: aws configure"
    exit 1
fi

echo ""

# Check if Lambda function exists
echo -n "Checking if Lambda function exists... "
if aws lambda get-function --function-name $FUNCTION_NAME --region $REGION > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
    LAMBDA_ARN=$(aws lambda get-function --function-name $FUNCTION_NAME --region $REGION --query 'Configuration.FunctionArn' --output text)
    echo "  Lambda ARN: $LAMBDA_ARN"
else
    echo -e "${RED}✗${NC}"
    echo -e "${RED}Error: Lambda function '$FUNCTION_NAME' not found${NC}"
    echo "Deploy Lambda first: ./deploy-lambda.sh"
    exit 1
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Step 1: Creating API Gateway${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Check if API already exists
EXISTING_API_ID=$(aws apigateway get-rest-apis --region $REGION --query "items[?name=='$API_NAME'].id" --output text)

if [ ! -z "$EXISTING_API_ID" ]; then
    echo -e "${YELLOW}⚠ API Gateway already exists with ID: $EXISTING_API_ID${NC}"
    read -p "Delete and recreate? (y/n): " confirm
    
    if [[ $confirm == "y" ]]; then
        echo "Deleting existing API Gateway..."
        aws apigateway delete-rest-api --rest-api-id $EXISTING_API_ID --region $REGION
        echo -e "${GREEN}✓ Deleted${NC}"
        sleep 2
    else
        echo "Using existing API Gateway"
        API_ID=$EXISTING_API_ID
    fi
fi

# Create new API if needed
if [ -z "$API_ID" ]; then
    echo "Creating REST API..."
    API_ID=$(aws apigateway create-rest-api \
      --name "$API_NAME" \
      --description "API Gateway for AI Auto-Scaling Lambda" \
      --region $REGION \
      --query 'id' \
      --output text)
    
    echo -e "${GREEN}✓ API Created${NC}"
    echo "  API ID: $API_ID"
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Step 2: Configuring API Resources${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Get root resource
echo "Getting root resource..."
ROOT_ID=$(aws apigateway get-resources \
  --rest-api-id $API_ID \
  --region $REGION \
  --query 'items[0].id' \
  --output text)

echo -e "${GREEN}✓ Root Resource ID: $ROOT_ID${NC}"

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Step 3: Creating POST Method${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Create POST method
echo "Creating POST method..."
aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $ROOT_ID \
  --http-method POST \
  --authorization-type NONE \
  --region $REGION > /dev/null

echo -e "${GREEN}✓ POST method created${NC}"

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Step 4: Integrating with Lambda${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Integrate with Lambda
echo "Integrating API with Lambda..."
aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $ROOT_ID \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations" \
  --region $REGION > /dev/null

echo -e "${GREEN}✓ Lambda integration configured${NC}"

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Step 5: Deploying API${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Create deployment
echo "Deploying API to $STAGE_NAME stage..."
DEPLOYMENT_ID=$(aws apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name $STAGE_NAME \
  --region $REGION \
  --query 'id' \
  --output text)

echo -e "${GREEN}✓ API deployed${NC}"
echo "  Deployment ID: $DEPLOYMENT_ID"

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Step 6: Setting Lambda Permissions${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Give API Gateway permission to invoke Lambda
echo "Granting API Gateway permission to invoke Lambda..."

# Remove existing permission if it exists
aws lambda remove-permission \
  --function-name $FUNCTION_NAME \
  --statement-id apigateway-invoke \
  --region $REGION 2>/dev/null || true

# Add new permission
aws lambda add-permission \
  --function-name $FUNCTION_NAME \
  --statement-id apigateway-invoke \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:$REGION:$ACCOUNT_ID:$API_ID/*/*" \
  --region $REGION > /dev/null

echo -e "${GREEN}✓ Permissions configured${NC}"

# Generate the API URL
API_URL="https://$API_ID.execute-api.$REGION.amazonaws.com/$STAGE_NAME"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✓ API Gateway Setup Complete!                                  ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${BLUE}API Details:${NC}"
echo "  API ID: $API_ID"
echo "  Region: $REGION"
echo "  Stage: $STAGE_NAME"
echo ""
echo -e "${BLUE}Your Lambda API URL:${NC}"
echo -e "  ${GREEN}$API_URL${NC}"
echo ""

# Save to file
echo "$API_URL" > lambda-url.txt
echo -e "${GREEN}✓ URL saved to lambda-url.txt${NC}"
echo ""

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Test Your API${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo "Test with curl:"
echo -e "${CYAN}curl -X POST $API_URL \\${NC}"
echo -e "${CYAN}  -H \"Content-Type: application/json\" \\${NC}"
echo -e "${CYAN}  -d '{${NC}"
echo -e "${CYAN}    \"action\": \"analyze\",${NC}"
echo -e "${CYAN}    \"alert_type\": \"test\",${NC}"
echo -e "${CYAN}    \"instance\": \"test-server\"${NC}"
echo -e "${CYAN}  }'${NC}"
echo ""

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Next Steps${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo "1. Update your n8n workflow:"
echo "   - Open: http://13.60.207.36:5678"
echo "   - Find 'Trigger Auto-Scaling' HTTP Request node"
echo "   - Change URL to: $API_URL"
echo ""

echo "2. Update Lambda with ASG name:"
echo -e "   ${CYAN}aws lambda update-function-configuration \\${NC}"
echo -e "   ${CYAN}     --function-name $FUNCTION_NAME \\${NC}"
echo -e "   ${CYAN}     --environment \"Variables={\\${NC}"
echo -e "   ${CYAN}       AUTO_SCALING_GROUP_NAME=ai-incident-autoscaler-ASG,\\${NC}"
echo -e "   ${CYAN}       MIN_CAPACITY=2,MAX_CAPACITY=10,\\${NC}"
echo -e "   ${CYAN}       SCALE_UP_INCREMENT=2,SCALE_DOWN_INCREMENT=1\\${NC}"
echo -e "   ${CYAN}     }\" \\${NC}"
echo -e "   ${CYAN}     --region $REGION${NC}"
echo ""

echo "3. Test end-to-end:"
echo -e "   ${CYAN}cd ~/n8n-infra-automation/ai-incident-detection${NC}"
echo -e "   ${CYAN}./test-incidents.sh${NC}"
echo ""

echo -e "${GREEN}Your system is now ready for real auto-scaling! 🚀${NC}\n"