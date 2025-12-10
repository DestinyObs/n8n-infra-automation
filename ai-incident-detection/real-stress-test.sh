#!/bin/bash

# Real CPU Stress - Triggers Actual Prometheus Alerts
# This stresses the HOST machine that node-exporter monitors

echo "════════════════════════════════════════════════════════════"
echo "  REAL ALERT TRIGGER - Stress Test"
echo "════════════════════════════════════════════════════════════"
echo ""

# Check if stress is installed
if ! command -v stress &> /dev/null; then
    echo "📦 Installing stress utility..."
    sudo apt-get update -qq
    sudo apt-get install -y stress
    echo "✅ Stress utility installed"
    echo ""
fi

echo "This will stress your server's CPU to trigger real Prometheus alerts."
echo ""
echo "⚠️  WARNING: This will use 90%+ CPU for 3 minutes"
echo "    - Prometheus will detect the spike"
echo "    - Alert will fire after 30-60 seconds"
echo "    - Alertmanager will send to n8n"
echo "    - n8n will analyze with AI"
echo "    - Slack will receive notification"
echo ""

read -p "Continue? (y/n): " confirm

if [[ $confirm != "y" ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Starting CPU Stress Test"
echo "════════════════════════════════════════════════════════════"
echo ""

# Get number of CPU cores
CORES=$(nproc)
echo "Detected $CORES CPU cores"
echo "Starting stress on $CORES cores at 95% for 180 seconds..."
echo ""

# Run stress in background
stress --cpu $CORES --timeout 180s &
STRESS_PID=$!

echo "✅ Stress test started (PID: $STRESS_PID)"
echo ""
echo "⏱️  Timeline:"
echo "  0:00 - CPU stress begins"
echo "  0:30 - Prometheus evaluates alert rule (for: 30s)"
echo "  0:30 - Alert fires → Alertmanager"
echo "  0:30 - Alertmanager → n8n webhook"
echo "  0:31 - n8n → AI analysis"
echo "  0:35 - Slack notification sent"
echo "  3:00 - Stress test ends"
echo ""

# Monitor for 180 seconds
echo "Monitoring for alerts (checking every 10 seconds)..."
echo ""

for i in {1..18}; do
    sleep 10
    
    # Check if alert is firing
    ALERTS=$(curl -s http://localhost:9090/api/v1/alerts | jq -r '.data.alerts[] | select(.state == "firing") | .labels.alertname' 2>/dev/null)
    
    if [ ! -z "$ALERTS" ]; then
        echo "🚨 ALERT FIRING: $ALERTS"
    else
        echo "⏳ Waiting for alert... (${i}0 seconds elapsed)"
    fi
done

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Stress Test Complete"
echo "════════════════════════════════════════════════════════════"
echo ""

# Check final status
ALERTS=$(curl -s http://localhost:9090/api/v1/alerts | jq -r '.data.alerts[] | select(.state == "firing") | .labels.alertname' 2>/dev/null)

if [ ! -z "$ALERTS" ]; then
    echo "✅ SUCCESS! Alerts were triggered:"
    echo "$ALERTS"
    echo ""
    echo "📱 Check your Slack channel for notifications!"
else
    echo "⚠️  No alerts detected. Possible issues:"
    echo "   1. Alert thresholds not reached"
    echo "   2. Alert evaluation period too long"
    echo "   3. Check Prometheus: http://localhost:9090/alerts"
fi

echo ""
echo "To view Prometheus alerts:"
echo "  http://localhost:9090/alerts"
echo ""
echo "To check n8n executions:"
echo "  http://13.60.207.36:5678"
echo "  Go to: Executions tab"
echo ""