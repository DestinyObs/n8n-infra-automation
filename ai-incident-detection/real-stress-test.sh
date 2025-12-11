#!/bin/bash

# REAL INFRASTRUCTURE STRESS TESTS - FIXED VERSION
# Issue: Previous version had wrong worker calculation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   REAL INFRASTRUCTURE STRESS TESTS - FIXED                        ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════╝${NC}\n"

# Check prerequisites
check_tool() {
    local tool=$1
    local install_cmd=$2
    
    if ! command -v $tool &> /dev/null; then
        echo -e "${YELLOW}⚠ $tool not found, installing...${NC}"
        eval $install_cmd
        echo -e "${GREEN}✓ $tool installed${NC}"
    else
        echo -e "${GREEN}✓ $tool found${NC}"
    fi
}

echo -e "${YELLOW}Checking required tools...${NC}\n"
check_tool "stress-ng" "sudo apt-get update -qq && sudo apt-get install -y stress-ng"
check_tool "apache2-utils" "sudo apt-get install -y apache2-utils"

# Get number of cores
CORES=$(nproc)
echo -e "\n${CYAN}System Info:${NC}"
echo "  CPU Cores: $CORES"
echo ""

# Helper function to monitor alerts
monitor_alerts() {
    local duration=$1
    local check_interval=10
    local elapsed=0
    
    echo -e "\n${CYAN}Monitoring for alerts (${duration}s)...${NC}\n"
    
    while [ $elapsed -lt $duration ]; do
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
        
        # Check Prometheus alerts
        alerts=$(curl -s http://localhost:9090/api/v1/alerts 2>/dev/null | \
                 jq -r '.data.alerts[] | select(.state == "firing") | "\(.labels.alertname) (\(.labels.severity))"' 2>/dev/null)
        
        if [ ! -z "$alerts" ]; then
            echo -e "${RED}🚨 ALERTS FIRING:${NC}"
            echo "$alerts"
            echo ""
        else
            echo -e "${YELLOW}⏳ Waiting for alerts... (${elapsed}/${duration}s)${NC}"
        fi
    done
}

# Menu
show_menu() {
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  REAL STRESS TEST OPTIONS${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo "1. Real CPU Stress (70-85% load) - Should trigger HighCPUUsage"
    echo "2. Real Critical CPU (90%+ load) - Should trigger CriticalCPUUsage"
    echo "3. Real Memory Stress (75%+ usage) - Should trigger HighMemoryUsage"
    echo "4. Real Disk I/O Stress - Should trigger high I/O wait"
    echo "5. Real HTTP Load Test (5xx errors) - Application stress"
    echo "6. Real HTTP Load Test (latency) - Response time stress"
    echo "7. Combined Stress (CPU + Memory) - Multi-resource pressure"
    echo "8. Check Current System Resources"
    echo "9. Check Active Prometheus Alerts"
    echo "10. Test Prometheus Connection"
    echo "0. Exit"
    echo ""
}

# Test 1: Real CPU Stress (70-85%) - FIXED
test_cpu_moderate() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  TEST 1: Real CPU Stress (70-85%)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    echo -e "${YELLOW}This will:${NC}"
    echo "  • Stress CPU to ~75% for 120 seconds"
    echo "  • Use $CORES CPU workers at 75% each"
    echo "  • Prometheus will detect via node-exporter"
    echo "  • Alert should fire after 30-40 seconds"
    echo "  • AI should recommend: VARIABLE (auto-scale or manual)"
    echo ""
    
    read -p "Continue? (y/n): " confirm
    [ "$confirm" != "y" ] && return
    
    echo -e "\n${GREEN}Starting CPU stress: $CORES workers at 75% load for 120s${NC}\n"
    
    # FIXED: Use all cores with 75% load instead of fraction of cores
    stress-ng --cpu $CORES --cpu-load 75 --timeout 120s --metrics-brief &
    STRESS_PID=$!
    
    monitor_alerts 120
    
    wait $STRESS_PID 2>/dev/null
    
    echo -e "\n${GREEN}✓ Test complete${NC}"
    echo -e "${CYAN}Check: Slack notifications, n8n executions${NC}\n"
}

# Test 2: Real Critical CPU (90%+) - FIXED
test_cpu_critical() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  TEST 2: Real Critical CPU (90%+)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    echo -e "${YELLOW}This will:${NC}"
    echo "  • Stress ALL $CORES cores to 95% for 120 seconds"
    echo "  • Alert should fire after 20-30 seconds"
    echo "  • AI should recommend: AUTO-SCALE (high confidence)"
    echo ""
    
    read -p "Continue? (y/n): " confirm
    [ "$confirm" != "y" ] && return
    
    echo -e "\n${GREEN}Starting CRITICAL CPU stress: $CORES workers at 95% load for 120s${NC}\n"
    
    # Use all cores at 95% load
    stress-ng --cpu $CORES --cpu-load 95 --timeout 120s --metrics-brief &
    STRESS_PID=$!
    
    monitor_alerts 120
    
    wait $STRESS_PID 2>/dev/null
    
    echo -e "\n${GREEN}✓ Test complete${NC}"
    echo -e "${CYAN}Check: Slack should show AUTO-SCALE recommendation${NC}\n"
}

# Test 3: Real Memory Stress - FIXED
test_memory() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  TEST 3: Real Memory Stress${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    # Get total memory
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    TARGET_MEM=$((TOTAL_MEM * 78 / 100))  # 78% to ensure we exceed 75% threshold
    
    echo -e "${YELLOW}This will:${NC}"
    echo "  • Allocate ${TARGET_MEM}MB (~78% of ${TOTAL_MEM}MB total)"
    echo "  • Hold memory for 120 seconds"
    echo "  • Alert should fire after 60 seconds"
    echo "  • AI should recommend: VARIABLE"
    echo ""
    
    read -p "Continue? (y/n): " confirm
    [ "$confirm" != "y" ] && return
    
    echo -e "\n${GREEN}Starting memory stress: ${TARGET_MEM}MB for 120s${NC}\n"
    
    stress-ng --vm 1 --vm-bytes ${TARGET_MEM}M --timeout 120s --metrics-brief &
    STRESS_PID=$!
    
    monitor_alerts 120
    
    wait $STRESS_PID 2>/dev/null
    
    echo -e "\n${GREEN}✓ Test complete${NC}\n"
}

# Test 4: Real Disk I/O Stress
test_disk_io() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  TEST 4: Real Disk I/O Stress${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    echo -e "${YELLOW}This will:${NC}"
    echo "  • Generate heavy disk I/O for 120 seconds"
    echo "  • May trigger disk usage or I/O wait alerts"
    echo "  • Creates temporary files in /tmp"
    echo ""
    
    read -p "Continue? (y/n): " confirm
    [ "$confirm" != "y" ] && return
    
    echo -e "\n${GREEN}Starting disk I/O stress for 120s${NC}\n"
    
    stress-ng --hdd 4 --hdd-bytes 1G --temp-path /tmp --timeout 120s --metrics-brief &
    STRESS_PID=$!
    
    monitor_alerts 120
    
    wait $STRESS_PID 2>/dev/null
    
    echo -e "\n${GREEN}✓ Test complete${NC}\n"
}

# Test 5: Real HTTP Load with 5xx Errors
test_http_5xx() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  TEST 5: Real HTTP Load (5xx Errors)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    echo -e "${YELLOW}This will:${NC}"
    echo "  • Trigger mock server to generate 15% 5xx errors"
    echo "  • Send continuous HTTP traffic for 120 seconds"
    echo "  • Alert should fire after 30-40 seconds"
    echo "  • AI should recommend: MANUAL (investigate server)"
    echo ""
    
    read -p "Continue? (y/n): " confirm
    [ "$confirm" != "y" ] && return
    
    # Start error simulation
    echo -e "\n${GREEN}Triggering 5xx error rate...${NC}"
    curl -s -X POST http://localhost:3000/api/simulate/errors \
        -H "Content-Type: application/json" \
        -d '{"rate": 0.15, "duration": 120000}' | jq '.' || echo "Mock server not responding"
    
    echo -e "\n${GREEN}Generating HTTP traffic with Apache Bench...${NC}\n"
    
    # Generate continuous traffic
    ab -n 5000 -c 10 http://localhost:3000/api/test > /dev/null 2>&1 &
    AB_PID=$!
    
    monitor_alerts 120
    
    wait $AB_PID 2>/dev/null
    
    echo -e "\n${GREEN}✓ Test complete${NC}"
    echo -e "${CYAN}Check: Slack should recommend MANUAL investigation${NC}\n"
}

# Test 6: Real HTTP Latency Test
test_http_latency() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  TEST 6: Real HTTP Latency${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    echo -e "${YELLOW}This will:${NC}"
    echo "  • Trigger mock server to add 3500ms response delay"
    echo "  • Send continuous HTTP traffic for 120 seconds"
    echo "  • Alert should fire after 60 seconds"
    echo "  • AI should recommend: AUTO-SCALE (capacity issue)"
    echo ""
    
    read -p "Continue? (y/n): " confirm
    [ "$confirm" != "y" ] && return
    
    # Start latency simulation
    echo -e "\n${GREEN}Triggering high latency...${NC}"
    curl -s -X POST http://localhost:3000/api/simulate/latency \
        -H "Content-Type: application/json" \
        -d '{"delayMs": 3500, "duration": 120000}' | jq '.' || echo "Mock server not responding"
    
    echo -e "\n${GREEN}Generating HTTP traffic...${NC}\n"
    
    # Generate traffic
    ab -n 1000 -c 5 http://localhost:3000/api/test > /dev/null 2>&1 &
    AB_PID=$!
    
    monitor_alerts 120
    
    wait $AB_PID 2>/dev/null
    
    echo -e "\n${GREEN}✓ Test complete${NC}"
    echo -e "${CYAN}Check: Slack should recommend AUTO-SCALE${NC}\n"
}

# Test 7: Combined Stress (CPU + Memory) - FIXED
test_combined() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  TEST 7: Combined Stress (CPU + Memory)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    TARGET_MEM=$((TOTAL_MEM * 65 / 100))  # 65% memory
    
    echo -e "${YELLOW}This will:${NC}"
    echo "  • Stress CPU: $CORES cores at 88%"
    echo "  • Stress Memory: ${TARGET_MEM}MB (~65% of total)"
    echo "  • Duration: 120 seconds"
    echo "  • Multiple alerts should fire"
    echo "  • AI should recommend: AUTO-SCALE (high confidence)"
    echo ""
    
    read -p "Continue? (y/n): " confirm
    [ "$confirm" != "y" ] && return
    
    echo -e "\n${GREEN}Starting combined stress test for 120s${NC}\n"
    
    stress-ng --cpu $CORES --cpu-load 88 \
              --vm 1 --vm-bytes ${TARGET_MEM}M \
              --timeout 120s --metrics-brief &
    STRESS_PID=$!
    
    monitor_alerts 120
    
    wait $STRESS_PID 2>/dev/null
    
    echo -e "\n${GREEN}✓ Test complete${NC}"
    echo -e "${CYAN}Check: Multiple alerts in Slack${NC}\n"
}

# Check system resources
check_resources() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Current System Resources${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    echo -e "${YELLOW}CPU:${NC}"
    mpstat 1 1 2>/dev/null | tail -n 1 || top -bn1 | grep "Cpu(s)" | head -n 1
    
    echo -e "\n${YELLOW}Memory:${NC}"
    free -h
    
    echo -e "\n${YELLOW}Disk:${NC}"
    df -h / | tail -n 1
    
    echo -e "\n${YELLOW}Load Average:${NC}"
    uptime
    
    echo ""
}

# Check active alerts
check_alerts() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Active Prometheus Alerts${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    alerts=$(curl -s http://localhost:9090/api/v1/alerts 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        firing=$(echo "$alerts" | jq -r '.data.alerts[] | select(.state == "firing")')
        
        if [ -z "$firing" ]; then
            echo -e "${GREEN}No alerts currently firing${NC}"
        else
            echo "$alerts" | jq -r '.data.alerts[] | select(.state == "firing") | 
                "Alert: \(.labels.alertname)\nSeverity: \(.labels.severity)\nValue: \(.annotations.metric_value)\n---"'
        fi
    else
        echo -e "${RED}Cannot connect to Prometheus at http://localhost:9090${NC}"
        echo -e "${YELLOW}Make sure Docker services are running:${NC}"
        echo "  docker-compose ps"
    fi
    
    echo ""
}

# Test Prometheus connection
test_prometheus() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Testing Prometheus Connection${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    echo -n "Testing Prometheus API... "
    if curl -s -f http://localhost:9090/-/healthy > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Connected${NC}"
        
        echo -e "\n${YELLOW}Current CPU usage:${NC}"
        CPU=$(curl -s 'http://localhost:9090/api/v1/query?query=100-(avg(rate(node_cpu_seconds_total{mode="idle"}[1m]))*100)' 2>/dev/null | \
              jq -r '.data.result[0].value[1]' 2>/dev/null)
        
        if [ ! -z "$CPU" ] && [ "$CPU" != "null" ]; then
            echo "  ${CPU}%"
        else
            echo -e "  ${YELLOW}No CPU data available (node-exporter may not be running)${NC}"
        fi
        
        echo -e "\n${YELLOW}Active targets:${NC}"
        curl -s http://localhost:9090/api/v1/targets 2>/dev/null | \
            jq -r '.data.activeTargets[] | "  \(.job): \(.health)"'
        
    else
        echo -e "${RED}✗ Failed${NC}"
        echo -e "\n${YELLOW}Troubleshooting:${NC}"
        echo "1. Check if services are running:"
        echo "   docker-compose ps"
        echo ""
        echo "2. Check Prometheus logs:"
        echo "   docker-compose logs prometheus"
        echo ""
        echo "3. Restart services:"
        echo "   docker-compose restart"
    fi
    
    echo ""
}

# Main loop
while true; do
    show_menu
    read -p "Select option: " choice
    
    case $choice in
        1) test_cpu_moderate ;;
        2) test_cpu_critical ;;
        3) test_memory ;;
        4) test_disk_io ;;
        5) test_http_5xx ;;
        6) test_http_latency ;;
        7) test_combined ;;
        8) check_resources ;;
        9) check_alerts ;;
        10) test_prometheus ;;
        0) 
            echo -e "\n${GREEN}Goodbye!${NC}\n"
            exit 0
            ;;
        *)
            echo -e "\n${RED}Invalid option${NC}\n"
            ;;
    esac
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    read -p "Press Enter to continue..."
done