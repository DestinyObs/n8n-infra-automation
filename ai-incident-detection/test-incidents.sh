#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MOCK_SERVER="http://localhost:3000"
PROMETHEUS="http://localhost:9090"
N8N="http://localhost:5678"

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  AI-Driven Incident Detection - Testing Suite         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}\n"

# Function to print section headers
print_header() {
    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  $1${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# Function to check service health
check_service() {
    local service=$1
    local url=$2
    
    echo -n "Checking $service... "
    
    if curl -s -f "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Running${NC}"
        return 0
    else
        echo -e "${RED}✗ Not responding${NC}"
        return 1
    fi
}

# Function to simulate incidents
simulate_incident() {
    local type=$1
    local description=$2
    
    print_header "$description"
    
    case $type in
        "cpu")
            echo "Simulating high CPU usage (90%+ for 60 seconds)..."
            curl -s -X POST "$MOCK_SERVER/api/simulate/cpu" \
                -H "Content-Type: application/json" \
                -d '{"intensity": 0.95, "duration": 60000}' | jq .
            ;;
        
        "memory")
            echo "Simulating high memory usage (500MB for 60 seconds)..."
            curl -s -X POST "$MOCK_SERVER/api/simulate/memory" \
                -H "Content-Type: application/json" \
                -d '{"sizeMB": 500, "duration": 60000}' | jq .
            ;;
        
        "5xx")
            echo "Simulating 5xx errors (30% error rate for 60 seconds)..."
            curl -s -X POST "$MOCK_SERVER/api/simulate/errors" \
                -H "Content-Type: application/json" \
                -d '{"rate": 0.3, "duration": 60000}' | jq .
            ;;
        
        "4xx")
            echo "Simulating 4xx errors (20% error rate for 60 seconds)..."
            curl -s -X POST "$MOCK_SERVER/api/simulate/errors" \
                -H "Content-Type: application/json" \
                -d '{"rate": 0.2, "duration": 60000}' | jq .
            ;;
        
        "latency")
            echo "Simulating high latency (3000ms for 60 seconds)..."
            curl -s -X POST "$MOCK_SERVER/api/simulate/latency" \
                -H "Content-Type: application/json" \
                -d '{"delayMs": 3000, "duration": 60000}' | jq .
            ;;
    esac
    
    echo -e "\n${GREEN}Simulation started!${NC}"
    echo "Monitor Prometheus alerts: $PROMETHEUS/alerts"
    echo "Check Slack for notifications"
    echo -e "\nWaiting 70 seconds for alert to trigger and workflow to complete..."
    
    for i in {70..1}; do
        echo -ne "${YELLOW}$i seconds remaining...${NC}\r"
        sleep 1
    done
    
    echo -e "\n${GREEN}Test complete!${NC}\n"
}

# Main menu
show_menu() {
    print_header "Test Options"
    
    echo "1. Test High CPU Usage Alert (80%+)"
    echo "2. Test Critical CPU Usage Alert (90%+)"
    echo "3. Test High Memory Usage Alert"
    echo "4. Test 5xx Error Rate Alert"
    echo "5. Test 4xx Error Rate Alert"
    echo "6. Test High Latency Alert"
    echo "7. Run All Tests (Sequential)"
    echo "8. Check System Status"
    echo "9. Generate Traffic Load"
    echo "0. Exit"
    echo ""
}

# Check system status
check_status() {
    print_header "System Status Check"
    
    check_service "Mock Server" "$MOCK_SERVER/health"
    check_service "Prometheus" "$PROMETHEUS/-/healthy"
    check_service "n8n" "$N8N/healthz"
    
    echo -e "\n${BLUE}Current Metrics:${NC}"
    curl -s "$MOCK_SERVER/api/status" | jq .
    
    echo -e "\n${BLUE}Active Prometheus Alerts:${NC}"
    curl -s "$PROMETHEUS/api/v1/alerts" | jq '.data.alerts[] | select(.state == "firing") | {alert: .labels.alertname, severity: .labels.severity, instance: .labels.instance}'
}

# Generate traffic load
generate_traffic() {
    print_header "Generating Traffic Load"
    
    echo "Sending 100 requests to the test endpoint..."
    
    for i in {1..100}; do
        curl -s "$MOCK_SERVER/api/test" > /dev/null &
        echo -ne "Requests sent: $i/100\r"
    done
    
    wait
    echo -e "\n${GREEN}Traffic generation complete!${NC}\n"
}

# Run all tests
run_all_tests() {
    print_header "Running All Tests"
    
    echo -e "${YELLOW}This will run all test scenarios sequentially.${NC}"
    echo -e "${YELLOW}Total estimated time: ~8 minutes${NC}\n"
    
    read -p "Continue? (y/n): " confirm
    
    if [[ $confirm != "y" ]]; then
        echo "Tests cancelled."
        return
    fi
    
    simulate_incident "cpu" "Test 1/5: High CPU Usage"
    sleep 10
    
    simulate_incident "memory" "Test 2/5: High Memory Usage"
    sleep 10
    
    simulate_incident "5xx" "Test 3/5: 5xx Error Rate"
    sleep 10
    
    simulate_incident "4xx" "Test 4/5: 4xx Error Rate"
    sleep 10
    
    simulate_incident "latency" "Test 5/5: High Latency"
    
    print_header "All Tests Complete!"
    echo -e "${GREEN}Check your Slack channel for all notifications${NC}\n"
}

# Check if services are running
print_header "Pre-flight Check"
check_service "Mock Server" "$MOCK_SERVER/health" || {
    echo -e "\n${RED}Error: Services not running. Please start with 'docker-compose up -d'${NC}\n"
    exit 1
}

# Main loop
while true; do
    show_menu
    read -p "Select option: " choice
    
    case $choice in
        1) simulate_incident "cpu" "High CPU Usage Test" ;;
        2) simulate_incident "cpu" "Critical CPU Usage Test" ;;
        3) simulate_incident "memory" "High Memory Usage Test" ;;
        4) simulate_incident "5xx" "5xx Error Rate Test" ;;
        5) simulate_incident "4xx" "4xx Error Rate Test" ;;
        6) simulate_incident "latency" "High Latency Test" ;;
        7) run_all_tests ;;
        8) check_status ;;
        9) generate_traffic ;;
        0) 
            echo -e "\n${GREEN}Goodbye!${NC}\n"
            exit 0
            ;;
        *)
            echo -e "\n${RED}Invalid option. Please try again.${NC}\n"
            ;;
    esac
done