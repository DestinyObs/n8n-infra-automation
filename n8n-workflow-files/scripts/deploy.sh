#!/bin/bash
# Quick Start Deployment Script for AI-Driven Incident Detection

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   AI-Driven Incident Detection & Auto-Scaling Deployment     ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"
MISSING_DEPS=()

if ! command_exists docker; then
    MISSING_DEPS+=("docker")
fi

if ! command_exists docker-compose; then
    MISSING_DEPS+=("docker-compose")
fi

if ! command_exists curl; then
    MISSING_DEPS+=("curl")
fi

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo -e "${RED}Missing dependencies: ${MISSING_DEPS[*]}${NC}"
    echo "Please install missing dependencies and run again."
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites met${NC}\n"

# Get configuration from user
echo -e "${YELLOW}Configuration Setup${NC}"
echo "Please provide the following information:"
echo ""

read -p "Server IP address [localhost]: " SERVER_IP
SERVER_IP=${SERVER_IP:-localhost}

read -sp "n8n admin password: " N8N_PASSWORD
echo ""

read -sp "Anthropic API key: " ANTHROPIC_API_KEY
echo ""

read -p "Slack Bot Token (optional): " SLACK_TOKEN

read -p "AWS API Gateway URL (optional): " LAMBDA_URL

read -p "Auto Scaling Group name [production-asg]: " ASG_NAME
ASG_NAME=${ASG_NAME:-production-asg}

# Create .env file
echo -e "\n${BLUE}Creating configuration file...${NC}"
cat > .env << EOF
# n8n Configuration
N8N_PASSWORD=${N8N_PASSWORD}
SERVER_IP=${SERVER_IP}

# API Keys
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
SLACK_TOKEN=${SLACK_TOKEN}

# AWS Configuration
LAMBDA_API_GATEWAY_URL=${LAMBDA_URL}
ASG_NAME=${ASG_NAME}
MIN_INSTANCES=2
MAX_INSTANCES=10
SCALE_UP_AMOUNT=2

# Slack
SLACK_CHANNEL=#devops-alerts
EOF

echo -e "${GREEN}✓ Configuration file created${NC}\n"

# Start n8n
echo -e "${BLUE}Starting n8n...${NC}"
docker-compose up -d

# Wait for n8n to be ready
echo "Waiting for n8n to start..."
for i in {1..30}; do
    if curl -s http://${SERVER_IP}:5678 > /dev/null; then
        echo -e "${GREEN}✓ n8n is ready!${NC}\n"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}✗ n8n failed to start${NC}"
        echo "Check logs with: docker-compose logs -f n8n"
        exit 1
    fi
    sleep 2
done

# Display next steps
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║                  Deployment Complete! 🎉                      ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${BLUE}Next Steps:${NC}\n"

echo "1. Access n8n:"
echo -e "   ${GREEN}http://${SERVER_IP}:5678${NC}"
echo -e "   Username: admin"
echo -e "   Password: (the one you entered)\n"

echo "2. Import workflow:"
echo -e "   • Go to n8n web interface"
echo -e "   • Click 'Import Workflow'"
echo -e "   • Select: ${YELLOW}configs/n8n-workflow-complete.json${NC}\n"

echo "3. Configure credentials:"
echo -e "   • Anthropic API (already configured)"
if [ -n "$SLACK_TOKEN" ]; then
    echo -e "   • Slack Bot Token (already configured)"
else
    echo -e "   • ${YELLOW}Add Slack credentials in n8n${NC}"
fi
if [ -n "$LAMBDA_URL" ]; then
    echo -e "   • AWS API Gateway (already configured)"
else
    echo -e "   • ${YELLOW}Add AWS API Gateway credentials when ready${NC}"
fi
echo ""

echo "4. Set up Prometheus (see README.md for details):"
echo -e "   ${YELLOW}cp prometheus/prometheus.yml /etc/prometheus/${NC}"
echo -e "   ${YELLOW}cp prometheus/alert_rules.yml /etc/prometheus/${NC}"
echo -e "   ${YELLOW}cp prometheus/alertmanager.yml /etc/alertmanager/${NC}\n"

echo "5. Deploy AWS Lambda (if using auto-scaling):"
echo -e "   ${YELLOW}cd lambda${NC}"
echo -e "   ${YELLOW}zip -r auto_scale_handler.zip auto_scale_handler.py${NC}"
echo -e "   ${YELLOW}aws lambda create-function ... (see README.md)${NC}\n"

echo "6. Test the workflow:"
echo -e "   ${YELLOW}cd scripts${NC}"
echo -e "   ${YELLOW}./test_workflow.sh${NC}\n"

echo -e "${BLUE}Documentation:${NC}"
echo -e "   • Full guide: ${GREEN}README.md${NC}"
echo -e "   • Workflow details: ${GREEN}incident-detection-workflow.md${NC}\n"

echo -e "${BLUE}Useful Commands:${NC}"
echo -e "   • View logs: ${YELLOW}docker-compose logs -f n8n${NC}"
echo -e "   • Stop services: ${YELLOW}docker-compose down${NC}"
echo -e "   • Restart n8n: ${YELLOW}docker-compose restart n8n${NC}"
echo -e "   • Run tests: ${YELLOW}cd scripts && ./test_workflow.sh${NC}\n"

echo -e "${GREEN}Happy monitoring! 🚀${NC}\n"