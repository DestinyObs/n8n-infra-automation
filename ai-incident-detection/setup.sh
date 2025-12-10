#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

clear

echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║     █████╗ ██╗      ██████╗ ██████╗ ██╗██╗   ██╗███████╗███╗   ██║
║    ██╔══██╗██║      ██╔══██╗██╔══██╗██║██║   ██║██╔════╝████╗  ██║
║    ███████║██║█████╗██║  ██║██████╔╝██║██║   ██║█████╗  ██╔██╗ ██║
║    ██╔══██║██║╚════╝██║  ██║██╔══██╗██║╚██╗ ██╔╝██╔══╝  ██║╚██╗██║
║    ██║  ██║██║      ██████╔╝██║  ██║██║ ╚████╔╝ ███████╗██║ ╚████║
║    ╚═╝  ╚═╝╚═╝      ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═══╝
║                                                                   ║
║         INCIDENT DETECTION & AUTO-SCALING SYSTEM                  ║
║                    Installation Script                            ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

# Check prerequisites
check_docker() {
    echo -n "Checking Docker installation... "
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        echo -e "${RED}Error: Docker is not installed${NC}"
        echo "Please install Docker: https://docs.docker.com/get-docker/"
        return 1
    fi
}

check_docker_compose() {
    echo -n "Checking Docker Compose installation... "
    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        echo -e "${RED}Error: Docker Compose is not installed${NC}"
        echo "Please install Docker Compose: https://docs.docker.com/compose/install/"
        return 1
    fi
}

check_curl() {
    echo -n "Checking curl installation... "
    if command -v curl &> /dev/null; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        echo -e "${RED}Error: curl is not installed${NC}"
        return 1
    fi
}

check_jq() {
    echo -n "Checking jq installation... "
    if command -v jq &> /dev/null; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Optional${NC} (recommended for testing)"
        return 0
    fi
}

# Prerequisites check
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Prerequisites Check${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

check_docker || exit 1
check_docker_compose || exit 1
check_curl || exit 1
check_jq

echo ""

# Configuration check
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Configuration Check${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

if [ -f .env ]; then
    echo -e "${GREEN}✓${NC} .env file found"
    
    if grep -q "GEMINI_API_KEY=AIzaSy" .env; then
        echo -e "${GREEN}✓${NC} Gemini API key configured"
    else
        echo -e "${YELLOW}⚠${NC} Gemini API key may need verification"
    fi
    
    if grep -q "SLACK_WEBHOOK_URL=https://hooks.slack.com" .env; then
        echo -e "${GREEN}✓${NC} Slack webhook URL configured"
    else
        echo -e "${YELLOW}⚠${NC} Slack webhook URL may need verification"
    fi
else
    echo -e "${RED}✗${NC} .env file not found!"
    exit 1
fi

echo ""

# Build confirmation
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Ready to Build and Deploy${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo "This will:"
echo "  1. Build Docker images"
echo "  2. Create Docker volumes"
echo "  3. Start all services (n8n, Prometheus, Alertmanager, etc.)"
echo "  4. Configure monitoring and alerting"
echo ""

read -p "Continue? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "\n${RED}Setup cancelled${NC}\n"
    exit 1
fi

echo ""

# Start deployment
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Starting Deployment${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Stop any existing containers
echo -e "${CYAN}Cleaning up existing containers...${NC}"
docker-compose down -v 2>/dev/null

# Build and start services
echo -e "\n${CYAN}Building Docker images...${NC}"
docker-compose build

echo -e "\n${CYAN}Starting services...${NC}"
docker-compose up -d

# Wait for services to be healthy
echo -e "\n${CYAN}Waiting for services to be ready...${NC}"
sleep 10

# Check service health
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Service Status${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

docker-compose ps

echo ""

# Make test script executable
chmod +x test-incidents.sh

# Success message
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✓ Deployment Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${PURPLE}🎯 Access Points:${NC}"
echo -e "   ${CYAN}n8n Automation:${NC}      http://localhost:5678"
echo -e "   ${CYAN}Prometheus:${NC}          http://localhost:9090"
echo -e "   ${CYAN}Alertmanager:${NC}        http://localhost:9093"
echo -e "   ${CYAN}Mock Server:${NC}         http://localhost:3000"

echo -e "\n${PURPLE}📋 Next Steps:${NC}"
echo -e "   1. Open n8n: ${CYAN}http://localhost:5678${NC}"
echo -e "   2. Create an account (first time only)"
echo -e "   3. Import workflow: ${CYAN}n8n-workflows/ai-incident-detection.json${NC}"
echo -e "   4. Activate the workflow (toggle in top-right)"
echo -e "   5. Run tests: ${CYAN}./test-incidents.sh${NC}"

echo -e "\n${PURPLE}🧪 Testing:${NC}"
echo -e "   ${CYAN}./test-incidents.sh${NC}    Launch interactive test menu"

echo -e "\n${PURPLE}📊 Monitoring:${NC}"
echo -e "   ${CYAN}docker-compose logs -f${NC}       View all logs"
echo -e "   ${CYAN}docker-compose logs -f n8n${NC}   View n8n logs"

echo -e "\n${PURPLE}🛑 Shutdown:${NC}"
echo -e "   ${CYAN}docker-compose down${NC}          Stop all services"
echo -e "   ${CYAN}docker-compose down -v${NC}       Stop and remove volumes"

echo -e "\n${GREEN}For detailed documentation, see: ${CYAN}README.md${NC}\n"