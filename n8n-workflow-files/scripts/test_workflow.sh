#!/bin/bash
# Test n8n Workflow - Send Test Alert

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get server IP from .env or use default
if [ -f "../.env" ]; then
    SERVER_IP=$(grep "SERVER_IP=" ../.env | cut -d '=' -f2)
else
    SERVER_IP="13.60.207.36"
fi

N8N_URL="http://${SERVER_IP}:5678/webhook/prometheus-alert"

echo "=========================================="
echo "n8n Workflow Test Script"
echo "=========================================="
echo ""
echo "Webhook URL: $N8N_URL"
echo ""

# Test 1: High CPU Alert
test_high_cpu() {
    echo -e "${BLUE}Test 1: High CPU Usage Alert${NC}"
    echo "Sending critical CPU alert..."
    
    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    curl -X POST "$N8N_URL" \
      -H "Content-Type: application/json" \
      -d "{
        \"alerts\": [{
          \"status\": \"firing\",
          \"labels\": {
            \"alertname\": \"HighCPUUsage\",
            \"instance\": \"node-exporter:9100\",
            \"severity\": \"critical\",
            \"type\": \"cpu\",
            \"environment\": \"production\"
          },
          \"annotations\": {
            \"summary\": \"High CPU usage detected on production server\",
            \"description\": \"CPU usage is 92% on production-server-1 for more than 2 minutes\",
            \"metric_value\": \"92\"
          },
          \"startsAt\": \"$TIMESTAMP\",
          \"generatorURL\": \"http://prometheus:9090/graph?g0.expr=node_cpu_usage&g0.tab=1\"
        }]
      }"
    
    echo ""
    echo -e "${GREEN}✓ CPU alert sent${NC}"
    echo ""
}

# Test 2: High Memory Alert
test_high_memory() {
    echo -e "${BLUE}Test 2: High Memory Usage Alert${NC}"
    echo "Sending memory alert..."
    
    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    curl -X POST "$N8N_URL" \
      -H "Content-Type: application/json" \
      -d "{
        \"alerts\": [{
          \"status\": \"firing\",
          \"labels\": {
            \"alertname\": \"HighMemoryUsage\",
            \"instance\": \"node-exporter:9100\",
            \"severity\": \"warning\",
            \"type\": \"memory\",
            \"environment\": \"production\"
          },
          \"annotations\": {
            \"summary\": \"High memory usage on production server\",
            \"description\": \"Memory usage is 88% on production-server-1\",
            \"metric_value\": \"88\"
          },
          \"startsAt\": \"$TIMESTAMP\",
          \"generatorURL\": \"http://prometheus:9090\"
        }]
      }"
    
    echo ""
    echo -e "${GREEN}✓ Memory alert sent${NC}"
    echo ""
}

# Test 3: 5xx Errors
test_5xx_errors() {
    echo -e "${BLUE}Test 3: High 5xx Error Rate${NC}"
    echo "Sending 5xx error alert..."
    
    curl -X POST "$N8N_URL" \
      -H "Content-Type: application/json" \
      -d '{
        "alerts": [{
          "status": "firing",
          "labels": {
            "alertname": "High5xxErrorRate",
            "instance": "app-server:8080",
            "severity": "critical",
            "type": "5xx_errors",
            "environment": "production"
          },
          "annotations": {
            "summary": "High 5xx error rate detected",
            "description": "5xx error rate is 8% of total requests",
            "metric_value": "8"
          },
          "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
          "generatorURL": "http://prometheus:9090"
        }]
      }'
    
    echo ""
    echo -e "${GREEN}✓ 5xx error alert sent${NC}"
    echo ""
}

# Test 4: Disk Space
test_disk_space() {
    echo -e "${BLUE}Test 4: High Disk Usage${NC}"
    echo "Sending disk space alert..."
    
    curl -X POST "$N8N_URL" \
      -H "Content-Type: application/json" \
      -d '{
        "alerts": [{
          "status": "firing",
          "labels": {
            "alertname": "HighDiskUsage",
            "instance": "node-exporter:9100",
            "severity": "warning",
            "type": "disk",
            "environment": "production"
          },
          "annotations": {
            "summary": "High disk usage on root partition",
            "description": "Disk usage is 87% on / mountpoint",
            "metric_value": "87"
          },
          "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
          "generatorURL": "http://prometheus:9090"
        }]
      }'
    
    echo ""
    echo -e "${GREEN}✓ Disk alert sent${NC}"
    echo ""
}

# Menu
show_menu() {
    echo "Select test to run:"
    echo "1) High CPU Usage (Critical)"
    echo "2) High Memory Usage (Warning)"
    echo "3) High 5xx Error Rate (Critical)"
    echo "4) High Disk Usage (Warning)"
    echo "5) Run All Tests"
    echo "6) Custom Test"
    echo "7) Exit"
    echo ""
    read -p "Enter choice [1-7]: " choice
    
    case $choice in
        1)
            test_high_cpu
            ;;
        2)
            test_high_memory
            ;;
        3)
            test_5xx_errors
            ;;
        4)
            test_disk_space
            ;;
        5)
            echo -e "${BLUE}Running All Tests${NC}"
            echo ""
            test_high_cpu
            sleep 2
            test_high_memory
            sleep 2
            test_5xx_errors
            sleep 2
            test_disk_space
            echo -e "${GREEN}✓ All tests completed${NC}"
            ;;
        6)
            read -p "Alert Name: " alert_name
            read -p "Severity (warning/critical): " severity
            read -p "Metric Value: " metric_value
            read -p "Description: " description
            
            curl -X POST "$N8N_URL" \
              -H "Content-Type: application/json" \
              -d '{
                "alerts": [{
                  "status": "firing",
                  "labels": {
                    "alertname": "'"$alert_name"'",
                    "instance": "custom-server:9100",
                    "severity": "'"$severity"'",
                    "type": "custom"
                  },
                  "annotations": {
                    "summary": "'"$description"'",
                    "description": "'"$description"'",
                    "metric_value": "'"$metric_value"'"
                  },
                  "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
                  "generatorURL": "http://prometheus:9090"
                }]
              }'
            echo ""
            echo -e "${GREEN}✓ Custom alert sent${NC}"
            ;;
        7)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            ;;
    esac
}

# Main
echo -e "${YELLOW}This script sends test alerts to your n8n workflow${NC}"
echo "Make sure:"
echo "  ✓ n8n is running on http://$SERVER_IP:5678"
echo "  ✓ Workflow is Active"
echo "  ✓ Slack webhook is configured in .env"
echo ""

while true; do
    show_menu
    echo ""
    echo "Check:"
    echo "  • n8n Executions: http://$SERVER_IP:5678/workflows/[workflow-id]/executions"
    echo "  • Slack channel for notifications"
    echo ""
    read -p "Run another test? (y/n): " continue
    if [[ $continue != "y" ]]; then
        break
    fi
    echo ""
done

echo ""
echo "=========================================="
echo "Testing Complete"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Check n8n executions to see workflow runs"
echo "2. Check Slack for alert notifications"
echo "3. Verify AI analysis in the messages"
echo ""
