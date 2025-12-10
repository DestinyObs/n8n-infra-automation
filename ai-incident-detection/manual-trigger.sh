#!/bin/bash

# Manual Alert Trigger - For Testing n8n Workflow
# This sends a test alert directly to n8n to verify the workflow works

echo "════════════════════════════════════════════════════════════"
echo "  MANUAL ALERT TRIGGER - Testing n8n Workflow"
echo "════════════════════════════════════════════════════════════"
echo ""

# Get your server IP
echo "Enter your server public IP (or press Enter for localhost):"
read -p "IP Address: " SERVER_IP

if [ -z "$SERVER_IP" ]; then
    SERVER_IP="localhost"
fi

N8N_URL="http://${SERVER_IP}:5678/webhook/prometheus-alert"

echo ""
echo "Sending test alert to: $N8N_URL"
echo ""

# Send test alert
response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$N8N_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "alerts": [
      {
        "status": "firing",
        "labels": {
          "alertname": "HighCPUUsage",
          "severity": "warning",
          "instance": "test-server",
          "type": "cpu",
          "environment": "production",
          "job": "node-exporter"
        },
        "annotations": {
          "summary": "High CPU usage detected on test-server",
          "description": "CPU usage is above 80% (current value: 92.5%)",
          "metric_value": "92.5%"
        },
        "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'",
        "endsAt": "0001-01-01T00:00:00Z",
        "generatorURL": "http://prometheus:9090/graph?...",
        "fingerprint": "test123"
      }
    ],
    "version": "4",
    "groupKey": "test",
    "truncatedAlerts": 0,
    "status": "firing",
    "receiver": "n8n-webhook",
    "groupLabels": {
      "alertname": "HighCPUUsage"
    },
    "commonLabels": {
      "alertname": "HighCPUUsage",
      "severity": "warning"
    },
    "commonAnnotations": {},
    "externalURL": "http://alertmanager:9093"
  }')

# Extract HTTP code
http_code=$(echo "$response" | grep "HTTP_CODE" | cut -d: -f2)
body=$(echo "$response" | grep -v "HTTP_CODE")

echo "Response Code: $http_code"
echo ""

if [ "$http_code" == "200" ]; then
    echo "✅ SUCCESS! Alert sent to n8n"
    echo ""
    echo "What should happen now:"
    echo "1. n8n receives the webhook"
    echo "2. n8n sends data to Gemini AI for analysis"
    echo "3. AI analyzes the alert and provides recommendation"
    echo "4. Slack receives notification with AI analysis"
    echo ""
    echo "⏰ Expected time: 10-30 seconds"
    echo "📱 Check your Slack channel for the notification!"
else
    echo "❌ FAILED! n8n did not respond"
    echo ""
    echo "Possible issues:"
    echo "1. n8n workflow is not activated"
    echo "2. Wrong server IP"
    echo "3. n8n container not running"
    echo ""
    echo "Troubleshooting:"
    echo "- Check n8n logs: docker logs n8n-automation"
    echo "- Verify workflow is activated in n8n UI"
    echo "- Test URL in browser: http://$SERVER_IP:5678"
fi

echo ""
echo "════════════════════════════════════════════════════════════"