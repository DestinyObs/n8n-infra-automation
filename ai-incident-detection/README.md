# AI-Driven Incident Detection & Auto-Scaling System

A production-ready DevOps automation system that uses AI to intelligently detect, analyze, and respond to infrastructure incidents in real-time.

## 🎯 Overview

This system provides:
- **Real-time Monitoring**: Prometheus monitors CPU, memory, disk, HTTP errors, and latency
- **AI Analysis**: Gemini AI analyzes incidents to determine severity and trends
- **Smart Alerting**: Rich Slack notifications with AI-powered insights
- **Auto-Scaling**: Automatic infrastructure scaling based on AI recommendations
- **Comprehensive Testing**: Built-in tools to simulate various incident scenarios

## 🏗️ Architecture

```
Prometheus (Monitor) → Alertmanager → n8n (Orchestration) → Gemini AI (Analysis)
                                            ↓
                                    Decision Engine
                                    ↙            ↘
                            Auto-Scale          Slack Alert
                            (AWS/Lambda)        (Notification)
```

## 📋 Prerequisites

- Docker & Docker Compose
- Linux/Mac system (or WSL2 on Windows)
- Active internet connection
- Slack workspace with webhook access
- Google Gemini API key

## 🚀 Quick Start

### 1. Clone and Setup

```bash
# Navigate to project directory
cd ai-incident-detection

# Make test script executable
chmod +x test-incidents.sh
```

### 2. Configure Environment

The `.env` file is already configured with your credentials:
- ✅ Gemini API Key
- ✅ Slack Webhook URL

No changes needed unless you want to customize AWS settings.

### 3. Start All Services

```bash
# Start the entire stack
docker-compose up -d

# Check service health
docker-compose ps
```

Expected output:
```
NAME              STATUS          PORTS
n8n-automation    Up (healthy)    0.0.0.0:5678->5678/tcp
prometheus        Up (healthy)    0.0.0.0:9090->9090/tcp
alertmanager      Up (healthy)    0.0.0.0:9093->9093/tcp
node-exporter     Up (healthy)    0.0.0.0:9100->9100/tcp
mock-server       Up (healthy)    0.0.0.0:3000->3000/tcp
```

### 4. Import n8n Workflow

1. Open n8n: `http://localhost:5678`
2. Create an account (first time only)
3. Go to **Workflows** → **Import**
4. Select: `n8n-workflows/ai-incident-detection.json`
5. Click **Activate** (toggle in top-right)

### 5. Run Tests

```bash
# Launch interactive test menu
./test-incidents.sh
```

## 📊 Service URLs

| Service | URL | Purpose |
|---------|-----|---------|
| **n8n** | http://localhost:5678 | Workflow automation |
| **Prometheus** | http://localhost:9090 | Metrics & alerts |
| **Alertmanager** | http://localhost:9093 | Alert management |
| **Mock Server** | http://localhost:3000 | Test application |

## 🧪 Testing Scenarios

The `test-incidents.sh` script provides 9 test scenarios:

### 1. High CPU Usage
Simulates CPU load above 80% threshold
- **Expected**: Warning alert → AI analysis → Slack notification
- **AI Decision**: Likely "auto-scale" if sustained

### 2. Critical CPU Usage
Simulates CPU load above 90% threshold
- **Expected**: Critical alert → AI analysis → Auto-scaling triggered
- **AI Decision**: High confidence "auto-scale"

### 3. High Memory Usage
Simulates memory pressure (85%+)
- **Expected**: Warning alert → AI analysis → Slack notification
- **AI Decision**: Varies based on pattern

### 4. 5xx Error Rate
Simulates server errors (30% error rate)
- **Expected**: Critical alert → AI analysis → Manual investigation
- **AI Decision**: Usually "manual" (investigate before scaling)

### 5. 4xx Error Rate
Simulates client errors (20% error rate)
- **Expected**: Warning alert → AI analysis → Manual investigation
- **AI Decision**: "manual" (application/client issue)

### 6. High Latency
Simulates slow response times (3000ms)
- **Expected**: Warning alert → AI analysis → Scaling recommendation
- **AI Decision**: Depends on load pattern

### 7. Run All Tests
Sequentially runs all scenarios (~8 minutes)

### 8. Check System Status
Shows current metrics and active alerts

### 9. Generate Traffic Load
Sends 100 requests to simulate activity

## 🤖 AI Analysis Features

The AI agent evaluates:

### 1. Spike Classification
- **Temporary**: Short bursts that resolve quickly
- **Consistent**: Sustained load indicating growth

### 2. Trend Prediction
- Load trajectory (increasing/stable/decreasing)
- Time horizon (15min/1hr/24hr)

### 3. Root Cause Analysis
- Normal traffic growth
- Sudden surge
- Resource leak
- External attack
- Application bug

### 4. Recommendations
- **auto-scale**: Trigger automatic scaling
- **manual**: Requires human investigation
- **no-action**: Monitor only

### 5. Confidence Score
- 0-100% confidence in the recommendation

## 📱 Slack Notifications

### Alert Notification
Includes:
- Alert details (name, instance, severity)
- Metric values
- AI analysis summary
- Confidence score
- Recommended action

### Scaling Notification
Sent when auto-scaling is triggered:
- Scaling action details
- AI decision factors
- Timestamp

### No-Action Notification
Sent when no scaling is needed:
- Incident summary
- AI reasoning
- Monitoring status

## 🔧 Configuration

### Prometheus Alert Rules
Edit `prometheus/alert.rules.yml`:
- Adjust thresholds
- Add new alert types
- Modify evaluation intervals

### n8n Workflow
Edit via n8n UI:
- Customize AI prompts
- Modify Slack message format
- Add email notifications
- Integrate AWS Lambda/ASG

### Mock Server
Edit `mock-server/server.js`:
- Change simulation parameters
- Add custom metrics
- Modify endpoints

## 🔍 Monitoring

### View Prometheus Metrics
```bash
# Check all metrics
curl http://localhost:9090/api/v1/query?query=up

# Check CPU usage
curl http://localhost:9090/api/v1/query?query=node_cpu_seconds_total

# Check active alerts
curl http://localhost:9090/api/v1/alerts
```

### View n8n Executions
1. Open n8n UI
2. Go to **Executions**
3. View workflow runs and logs

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f n8n
docker-compose logs -f prometheus
docker-compose logs -f mock-server
```

## 🛠️ Troubleshooting

### Services Not Starting
```bash
# Check Docker status
docker-compose ps

# View logs
docker-compose logs

# Restart services
docker-compose restart
```

### Webhook Not Receiving Alerts
1. Check n8n workflow is **activated**
2. Verify Alertmanager config: `prometheus/alertmanager.yml`
3. Test webhook manually:
```bash
curl -X POST http://localhost:5678/webhook/prometheus-alert \
  -H "Content-Type: application/json" \
  -d '{"alerts":[{"labels":{"alertname":"TestAlert"}}]}'
```

### AI Not Responding
1. Verify Gemini API key in `.env`
2. Check n8n logs: `docker-compose logs n8n`
3. Test API directly:
```bash
curl -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{"contents":[{"parts":[{"text":"Hello"}]}]}'
```

### Slack Not Receiving Messages
1. Verify webhook URL in `.env`
2. Test webhook directly:
```bash
curl -X POST YOUR_SLACK_WEBHOOK_URL \
  -H "Content-Type: application/json" \
  -d '{"text":"Test message"}'
```

## 🚀 Production Deployment

### 1. AWS Lambda Integration

Replace mock scaling endpoint with real AWS Lambda:

```javascript
// In n8n "Trigger Auto-Scaling" node
{
  "url": "https://your-lambda-url.amazonaws.com/scale",
  "headers": {
    "Authorization": "Bearer YOUR_TOKEN"
  },
  "body": {
    "action": "scale_up",
    "instanceType": "t3.medium",
    "desiredCount": 3
  }
}
```

### 2. Auto Scaling Group Setup

Create Lambda function to manage ASG:

```python
import boto3

def lambda_handler(event, context):
    asg = boto3.client('autoscaling')
    
    response = asg.set_desired_capacity(
        AutoScalingGroupName='your-asg-name',
        DesiredCapacity=event['desiredCount']
    )
    
    return {
        'statusCode': 200,
        'body': 'Scaling initiated'
    }
```

### 3. Security Best Practices

1. **Use HTTPS**: Configure SSL/TLS for n8n
2. **Secure Webhooks**: Add authentication tokens
3. **Rotate Keys**: Regularly update API keys
4. **Network Isolation**: Use VPCs and security groups
5. **Audit Logs**: Enable CloudWatch logging

### 4. High Availability

1. **Run Multiple n8n Instances**: Use Redis for queue
2. **Prometheus HA**: Set up federation
3. **Database Backups**: Regular snapshots
4. **Disaster Recovery**: Multi-region setup

## 📈 Scaling Considerations

### Horizontal Scaling
- Add more Prometheus instances
- Use Thanos for long-term storage
- Deploy n8n in HA mode

### Vertical Scaling
- Increase container resources
- Optimize alert rules
- Tune AI model parameters

## 🤝 Contributing

This is a production-ready template. Customize for your needs:
- Add more alert rules
- Integrate with other monitoring tools
- Enhance AI prompts
- Add custom metrics

## 📄 License

MIT License - feel free to use and modify for your projects.

## 🆘 Support

For issues or questions:
1. Check logs: `docker-compose logs -f`
2. Review Prometheus alerts: http://localhost:9090/alerts
3. Verify n8n executions: http://localhost:5678
4. Test with `./test-incidents.sh`

---

**Built with ❤️ for DevOps Excellence**