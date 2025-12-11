#!/bin/bash

# Test AWS Lambda Function
# Sends test scaling requests to verify Lambda is working

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   AWS Lambda Auto-Scaling Test                                   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════╝${NC}\n"

# Check if Lambda URL exists
if [ -f lambda-url.txt ]; then
    source lambda-url.txt
elif [ ! -z "$AWS_LAMBDA_URL" ]; then
    echo -e "${GREEN}✓ Using AWS_LAMBDA_URL from environment${NC}"
else
    echo -e "${RED}✗ Lambda URL not found${NC}"
    echo "Run ./deploy-lambda.sh first to deploy the Lambda function"
    exit 1
fi

echo -e "${BLUE}Lambda URL:${NC} $AWS_LAMBDA_URL\n"

# Test menu
show_menu() {
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  Test Options${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo "1. Test Scale UP (High CPU)"
    echo "2. Test Scale UP (Critical CPU)"
    echo "3. Test Scale DOWN"
    echo "4. Get Current ASG Status"
    echo "5. Test with Custom Values"
    echo "0. Exit"
    echo ""
}

# Test scale up
test_scale_up() {
    local severity=$1
    local confidence=$2
    
    echo -e "\n${YELLOW}Testing Scale UP...${NC}\n"
    
    response=$(curl -s -X POST "$AWS_LAMBDA_URL" \
        -H "Content-Type: application/json" \
        -d "{
            \"action\": \"scale_up\",
            \"alert_type\": \"cpu\",
            \"instance\": \"test-server\",
            \"severity\": \"$severity\",
            \"metric_value\": \"92%\",
            \"ai_confidence\": $confidence,
            \"ai_reasoning\": \"Sustained CPU load indicates traffic growth\",
            \"environment\": \"production\"
        }")
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Request successful${NC}\n"
        echo "$response" | jq .
        
        if echo "$response" | jq -e '.body' > /dev/null 2>&1; then
            echo "$response" | jq -r '.body' | jq .
        fi
    else
        echo -e "${RED}✗ Request failed${NC}"
        echo "$response"
    fi
}

# Test scale down
test_scale_down() {
    echo -e "\n${YELLOW}Testing Scale DOWN...${NC}\n"
    
    response=$(curl -s -X POST "$AWS_LAMBDA_URL" \
        -H "Content-Type: application/json" \
        -d '{
            "action": "scale_down",
            "alert_type": "manual",
            "instance": "test-server",
            "severity": "info",
            "ai_confidence": 80,
            "ai_reasoning": "Load decreased, safe to scale down"
        }')
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Request successful${NC}\n"
        echo "$response" | jq .
        
        if echo "$response" | jq -e '.body' > /dev/null 2>&1; then
            echo "$response" | jq -r '.body' | jq .
        fi
    else
        echo -e "${RED}✗ Request failed${NC}"
        echo "$response"
    fi
}

# Get ASG status
get_status() {
    echo -e "\n${YELLOW}Getting ASG Status...${NC}\n"
    
    response=$(curl -s -X POST "$AWS_LAMBDA_URL" \
        -H "Content-Type: application/json" \
        -d '{
            "action": "analyze",
            "alert_type": "status_check"
        }')
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Request successful${NC}\n"
        echo "$response" | jq .
        
        if echo "$response" | jq -e '.body' > /dev/null 2>&1; then
            echo "$response" | jq -r '.body' | jq .
        fi
    else
        echo -e "${RED}✗ Request failed${NC}"
        echo "$response"
    fi
}

# Custom test
test_custom() {
    echo -e "\n${YELLOW}Custom Test${NC}\n"
    
    read -p "Action (scale_up/scale_down/analyze): " action
    read -p "Alert Type (cpu/memory/http_5xx/latency): " alert_type
    read -p "Severity (warning/critical): " severity
    read -p "AI Confidence (0-100): " confidence
    
    echo -e "\n${YELLOW}Sending request...${NC}\n"
    
    response=$(curl -s -X POST "$AWS_LAMBDA_URL" \
        -H "Content-Type: application/json" \
        -d "{
            \"action\": \"$action\",
            \"alert_type\": \"$alert_type\",
            \"instance\": \"custom-test\",
            \"severity\": \"$severity\",
            \"metric_value\": \"85%\",
            \"ai_confidence\": $confidence,
            \"ai_reasoning\": \"Custom test execution\"
        }")
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Request successful${NC}\n"
        echo "$response" | jq .
        
        if echo "$response" | jq -e '.body' > /dev/null 2>&1; then
            echo "$response" | jq -r '.body' | jq .
        fi
    else
        echo -e "${RED}✗ Request failed${NC}"
        echo "$response"
    fi
}

# Main loop
while true; do
    show_menu
    read -p "Select option: " choice
    
    case $choice in
        1)
            test_scale_up "warning" 85
            ;;
        2)
            test_scale_up "critical" 95
            ;;
        3)
            test_scale_down
            ;;
        4)
            get_status
            ;;
        5)
            test_custom
            ;;
        0)
            echo -e "\n${GREEN}Goodbye!${NC}\n"
            exit 0
            ;;
        *)
            echo -e "\n${RED}Invalid option${NC}\n"
            ;;
    esac
    
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    read -p "Press Enter to continue..."
done