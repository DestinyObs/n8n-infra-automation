#!/bin/bash
# Stress Test Script - Generate System Load for Testing

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "System Stress Test Script"
echo "=========================================="
echo ""

# Check if stress tools are installed
check_dependencies() {
    echo "Checking dependencies..."
    
    if ! command -v stress &> /dev/null; then
        echo -e "${YELLOW}Warning: 'stress' not installed. Installing...${NC}"
        sudo apt-get update && sudo apt-get install -y stress
    fi
    
    if ! command -v stress-ng &> /dev/null; then
        echo -e "${YELLOW}Warning: 'stress-ng' not installed. Installing...${NC}"
        sudo apt-get install -y stress-ng
    fi
    
    echo -e "${GREEN}✓ All dependencies installed${NC}"
    echo ""
}

# CPU Stress Test
cpu_stress_test() {
    local duration=${1:-300}  # Default 5 minutes
    local cpu_load=${2:-85}   # Default 85%
    local cpu_count=${3:-4}   # Default 4 CPUs
    
    echo -e "${BLUE}Starting CPU Stress Test${NC}"
    echo "Duration: ${duration} seconds"
    echo "Target Load: ${cpu_load}%"
    echo "CPU Count: ${cpu_count}"
    echo ""
    
    echo "Current CPU usage before test:"
    top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}'
    echo ""
    
    echo -e "${YELLOW}Starting stress test in 3 seconds...${NC}"
    sleep 3
    
    # Start CPU stress
    stress-ng --cpu $cpu_count --cpu-load $cpu_load --timeout ${duration}s &
    STRESS_PID=$!
    
    echo -e "${GREEN}✓ CPU stress test started (PID: $STRESS_PID)${NC}"
    echo "Monitor with: watch -n 1 'top -bn1 | head -n 20'"
    echo ""
    
    # Monitor for first 30 seconds
    echo "Monitoring CPU usage (first 30 seconds):"
    for i in {1..6}; do
        sleep 5
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
        echo "  $((i*5))s: CPU Usage = $cpu_usage"
    done
    
    echo ""
    echo "Test will continue for $((duration - 30)) more seconds..."
    echo "Press Ctrl+C to stop early"
    
    wait $STRESS_PID
    echo -e "${GREEN}✓ CPU stress test completed${NC}"
    echo ""
}

# Memory Stress Test
memory_stress_test() {
    local duration=${1:-300}  # Default 5 minutes
    local memory_gb=${2:-2}   # Default 2GB
    
    echo -e "${BLUE}Starting Memory Stress Test${NC}"
    echo "Duration: ${duration} seconds"
    echo "Memory to allocate: ${memory_gb}GB"
    echo ""
    
    echo "Current memory usage before test:"
    free -h | grep Mem
    echo ""
    
    echo -e "${YELLOW}Starting stress test in 3 seconds...${NC}"
    sleep 3
    
    # Start memory stress
    stress --vm 1 --vm-bytes ${memory_gb}G --timeout ${duration}s &
    STRESS_PID=$!
    
    echo -e "${GREEN}✓ Memory stress test started (PID: $STRESS_PID)${NC}"
    echo "Monitor with: watch -n 1 free -h"
    echo ""
    
    # Monitor for first 30 seconds
    echo "Monitoring memory usage (first 30 seconds):"
    for i in {1..6}; do
        sleep 5
        echo "  $((i*5))s:"
        free -h | grep Mem
    done
    
    wait $STRESS_PID
    echo -e "${GREEN}✓ Memory stress test completed${NC}"
    echo ""
}

# Combined Stress Test
combined_stress_test() {
    local duration=${1:-300}
    
    echo -e "${BLUE}Starting Combined Stress Test${NC}"
    echo "Duration: ${duration} seconds"
    echo "Testing: CPU (4 cores @ 85%) + Memory (2GB)"
    echo ""
    
    echo -e "${YELLOW}Starting combined test in 3 seconds...${NC}"
    sleep 3
    
    # Combined stress
    stress-ng --cpu 4 --cpu-load 85 --vm 1 --vm-bytes 2G --timeout ${duration}s &
    STRESS_PID=$!
    
    echo -e "${GREEN}✓ Combined stress test started (PID: $STRESS_PID)${NC}"
    echo ""
    
    # Monitor
    echo "Monitoring system (first 30 seconds):"
    for i in {1..6}; do
        sleep 5
        echo "  --- $((i*5))s ---"
        echo "  CPU:"
        top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print "    Usage: " 100 - $1"%"}'
        echo "  Memory:"
        free -h | grep Mem | awk '{print "    Used: "$3" / "$2}'
    done
    
    wait $STRESS_PID
    echo -e "${GREEN}✓ Combined stress test completed${NC}"
    echo ""
}

# IO Stress Test
io_stress_test() {
    local duration=${1:-300}
    local workers=${2:-4}
    
    echo -e "${BLUE}Starting I/O Stress Test${NC}"
    echo "Duration: ${duration} seconds"
    echo "Workers: ${workers}"
    echo ""
    
    echo "Current disk usage:"
    df -h / | tail -n 1
    echo ""
    
    echo -e "${YELLOW}Starting I/O stress test in 3 seconds...${NC}"
    sleep 3
    
    # Create temp directory for I/O test
    TEMP_DIR="/tmp/io-stress-test"
    mkdir -p $TEMP_DIR
    
    # Start I/O stress
    stress-ng --io $workers --hdd 2 --hdd-bytes 512M --temp-path $TEMP_DIR --timeout ${duration}s &
    STRESS_PID=$!
    
    echo -e "${GREEN}✓ I/O stress test started (PID: $STRESS_PID)${NC}"
    echo ""
    
    wait $STRESS_PID
    
    # Cleanup
    rm -rf $TEMP_DIR
    echo -e "${GREEN}✓ I/O stress test completed${NC}"
    echo ""
}

# Menu
show_menu() {
    echo "Select stress test type:"
    echo "1) CPU Stress (85% load, 5 minutes)"
    echo "2) Memory Stress (2GB, 5 minutes)"
    echo "3) Combined CPU + Memory (5 minutes)"
    echo "4) I/O Stress (4 workers, 5 minutes)"
    echo "5) Quick Test (All tests, 1 minute each)"
    echo "6) Custom CPU Test"
    echo "7) Exit"
    echo ""
    read -p "Enter choice [1-7]: " choice
    
    case $choice in
        1)
            cpu_stress_test 300 85 4
            ;;
        2)
            memory_stress_test 300 2
            ;;
        3)
            combined_stress_test 300
            ;;
        4)
            io_stress_test 300 4
            ;;
        5)
            echo -e "${BLUE}Running Quick Test Suite${NC}"
            echo ""
            cpu_stress_test 60 90 2
            sleep 5
            memory_stress_test 60 1
            sleep 5
            combined_stress_test 60
            echo -e "${GREEN}✓ Quick test suite completed${NC}"
            ;;
        6)
            read -p "Duration (seconds): " duration
            read -p "CPU Load (%): " cpu_load
            read -p "Number of CPUs: " cpu_count
            cpu_stress_test $duration $cpu_load $cpu_count
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
check_dependencies

while true; do
    show_menu
    echo ""
    read -p "Run another test? (y/n): " continue
    if [[ $continue != "y" ]]; then
        break
    fi
    echo ""
done

echo ""
echo "=========================================="
echo "Stress Testing Complete"
echo "=========================================="
echo ""
echo "Check your monitoring system for alerts:"
echo "• Prometheus: http://localhost:9090/alerts"
echo "• n8n: http://localhost:5678"
echo "• Slack: #devops-alerts channel"
echo ""