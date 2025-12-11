#!/bin/bash

# Auto Scaling Group Setup Script
# Creates a complete ASG with launch template for real infrastructure scaling

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Auto Scaling Group Setup                                       ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════╝${NC}\n"

# Configuration
ASG_NAME="ai-incident-autoscaler-ASG"
LAUNCH_TEMPLATE_NAME="ai-autoscaler-template"
REGION="us-east-1"

echo -e "${YELLOW}This script will create:${NC}"
echo "  1. Launch Template (EC2 configuration)"
echo "  2. Auto Scaling Group (2-10 instances)"
echo "  3. Scaling policies (CPU-based)"
echo ""

# Check AWS CLI
echo -n "Checking AWS CLI... "
if aws sts get-caller-identity > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
else
    echo -e "${RED}✗${NC}"
    echo -e "${RED}Error: AWS CLI not configured${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Step 1: Gather Information${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Get available AMIs (Amazon Linux 2023)
echo "Finding latest Amazon Linux 2023 AMI..."
AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-2023*-x86_64" \
          "Name=state,Values=available" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text \
  --region $REGION)

echo -e "${GREEN}✓ Found AMI: $AMI_ID${NC}"

# Get VPCs
echo ""
echo "Available VPCs:"
aws ec2 describe-vpcs \
  --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0],IsDefault]' \
  --output table \
  --region $REGION

echo ""
read -p "Enter VPC ID (or press Enter for default VPC): " VPC_ID

if [ -z "$VPC_ID" ]; then
    VPC_ID=$(aws ec2 describe-vpcs \
      --filters "Name=isDefault,Values=true" \
      --query 'Vpcs[0].VpcId' \
      --output text \
      --region $REGION)
    echo "Using default VPC: $VPC_ID"
fi

# Get subnets in the VPC
echo ""
echo "Available Subnets in VPC $VPC_ID:"
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock,Tags[?Key==`Name`].Value|[0]]' \
  --output table \
  --region $REGION

echo ""
echo "Enter subnet IDs (comma-separated, e.g., subnet-abc123,subnet-def456)"
echo "Tip: Use at least 2 subnets in different availability zones for HA"
read -p "Subnets: " SUBNET_INPUT

# Convert comma-separated subnets to array
IFS=',' read -ra SUBNETS <<< "$SUBNET_INPUT"
SUBNET_IDS=$(echo "${SUBNETS[@]}" | tr ' ' ',')

echo ""
echo -e "${GREEN}✓ Will use subnets: $SUBNET_IDS${NC}"

# Get key pairs
echo ""
echo "Available Key Pairs:"
aws ec2 describe-key-pairs \
  --query 'KeyPairs[*].[KeyName,KeyPairId]' \
  --output table \
  --region $REGION

echo ""
read -p "Enter Key Pair name (or press Enter to skip): " KEY_NAME

# Instance type
echo ""
echo -e "${YELLOW}Instance Type Selection:${NC}"
echo "  t3.micro   - 2 vCPU, 1 GB RAM   (~$7.50/month)"
echo "  t3.small   - 2 vCPU, 2 GB RAM   (~$15/month)"
echo "  t3.medium  - 2 vCPU, 4 GB RAM   (~$30/month)"
echo "  t2.micro   - 1 vCPU, 1 GB RAM   (~$8.50/month - Free tier eligible)"
echo ""
read -p "Enter instance type (default: t3.micro): " INSTANCE_TYPE
INSTANCE_TYPE=${INSTANCE_TYPE:-t3.micro}

# Capacity
echo ""
read -p "Minimum instances (default: 2): " MIN_SIZE
MIN_SIZE=${MIN_SIZE:-2}

read -p "Maximum instances (default: 10): " MAX_SIZE
MAX_SIZE=${MAX_SIZE:-10}

read -p "Desired instances (default: 2): " DESIRED_SIZE
DESIRED_SIZE=${DESIRED_SIZE:-2}

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Step 2: Creating Security Group${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Create security group
SG_NAME="ai-autoscaler-sg"
echo "Creating security group: $SG_NAME..."

# Check if security group exists
EXISTING_SG=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=$SG_NAME" "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' \
  --output text \
  --region $REGION 2>/dev/null || echo "None")

if [ "$EXISTING_SG" != "None" ]; then
    echo -e "${YELLOW}⚠ Security group already exists: $EXISTING_SG${NC}"
    SECURITY_GROUP_ID=$EXISTING_SG
else
    SECURITY_GROUP_ID=$(aws ec2 create-security-group \
      --group-name "$SG_NAME" \
      --description "Security group for AI Auto-Scaling instances" \
      --vpc-id "$VPC_ID" \
      --region $REGION \
      --query 'GroupId' \
      --output text)
    
    echo -e "${GREEN}✓ Security group created: $SECURITY_GROUP_ID${NC}"
    
    # Add inbound rules
    echo "Adding security group rules..."
    
    # SSH access
    aws ec2 authorize-security-group-ingress \
      --group-id $SECURITY_GROUP_ID \
      --protocol tcp \
      --port 22 \
      --cidr 0.0.0.0/0 \
      --region $REGION 2>/dev/null || true
    
    # HTTP
    aws ec2 authorize-security-group-ingress \
      --group-id $SECURITY_GROUP_ID \
      --protocol tcp \
      --port 80 \
      --cidr 0.0.0.0/0 \
      --region $REGION 2>/dev/null || true
    
    # HTTPS
    aws ec2 authorize-security-group-ingress \
      --group-id $SECURITY_GROUP_ID \
      --protocol tcp \
      --port 443 \
      --cidr 0.0.0.0/0 \
      --region $REGION 2>/dev/null || true
    
    # Node Exporter (for Prometheus)
    aws ec2 authorize-security-group-ingress \
      --group-id $SECURITY_GROUP_ID \
      --protocol tcp \
      --port 9100 \
      --cidr 0.0.0.0/0 \
      --region $REGION 2>/dev/null || true
    
    echo -e "${GREEN}✓ Security group rules added${NC}"
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Step 3: Creating Launch Template${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Create user data script for instances
USER_DATA=$(cat <<'EOF'
#!/bin/bash
# User data script for Auto Scaling instances

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Install Node Exporter for Prometheus monitoring
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvfz node_exporter-1.7.0.linux-amd64.tar.gz
cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-1.7.0.linux-amd64*

# Create systemd service for Node Exporter
cat > /etc/systemd/system/node_exporter.service <<'SERVICE'
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
User=ec2-user
ExecStart=/usr/local/bin/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl start node_exporter
systemctl enable node_exporter

# Install CloudWatch agent (optional)
yum install -y amazon-cloudwatch-agent

# Create a simple web server for testing
cat > /home/ec2-user/index.html <<HTML
<!DOCTYPE html>
<html>
<head>
    <title>Auto-Scaled Instance</title>
</head>
<body>
    <h1>Auto-Scaled Instance</h1>
    <p>Hostname: $(hostname)</p>
    <p>Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
    <p>Availability Zone: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</p>
</body>
</html>
HTML

# Start simple web server
cd /home/ec2-user
nohup python3 -m http.server 80 &

echo "Instance setup complete!"
EOF
)

# Encode user data to base64
USER_DATA_BASE64=$(echo "$USER_DATA" | base64 -w 0)

# Build launch template data
TEMPLATE_DATA="{
  \"ImageId\": \"$AMI_ID\",
  \"InstanceType\": \"$INSTANCE_TYPE\",
  \"SecurityGroupIds\": [\"$SECURITY_GROUP_ID\"],
  \"UserData\": \"$USER_DATA_BASE64\",
  \"TagSpecifications\": [{
    \"ResourceType\": \"instance\",
    \"Tags\": [
      {\"Key\": \"Name\", \"Value\": \"AI-AutoScaled-Instance\"},
      {\"Key\": \"ManagedBy\", \"Value\": \"AI-AutoScaler\"},
      {\"Key\": \"Environment\", \"Value\": \"production\"}
    ]
  }],
  \"Monitoring\": {\"Enabled\": true}"

# Add key name if provided
if [ ! -z "$KEY_NAME" ]; then
    TEMPLATE_DATA="${TEMPLATE_DATA},\"KeyName\": \"$KEY_NAME\""
fi

TEMPLATE_DATA="${TEMPLATE_DATA}}"

# Check if template exists
EXISTING_TEMPLATE=$(aws ec2 describe-launch-templates \
  --filters "Name=launch-template-name,Values=$LAUNCH_TEMPLATE_NAME" \
  --query 'LaunchTemplates[0].LaunchTemplateId' \
  --output text \
  --region $REGION 2>/dev/null || echo "None")

if [ "$EXISTING_TEMPLATE" != "None" ]; then
    echo -e "${YELLOW}⚠ Launch template already exists${NC}"
    echo "Creating new version..."
    
    aws ec2 create-launch-template-version \
      --launch-template-name "$LAUNCH_TEMPLATE_NAME" \
      --launch-template-data "$TEMPLATE_DATA" \
      --region $REGION > /dev/null
    
    # Set as default version
    LATEST_VERSION=$(aws ec2 describe-launch-templates \
      --filters "Name=launch-template-name,Values=$LAUNCH_TEMPLATE_NAME" \
      --query 'LaunchTemplates[0].LatestVersionNumber' \
      --output text \
      --region $REGION)
    
    aws ec2 modify-launch-template \
      --launch-template-name "$LAUNCH_TEMPLATE_NAME" \
      --default-version "$LATEST_VERSION" \
      --region $REGION > /dev/null
    
    echo -e "${GREEN}✓ Launch template updated (version $LATEST_VERSION)${NC}"
else
    echo "Creating launch template..."
    
    aws ec2 create-launch-template \
      --launch-template-name "$LAUNCH_TEMPLATE_NAME" \
      --version-description "AI Auto-Scaler Launch Template" \
      --launch-template-data "$TEMPLATE_DATA" \
      --region $REGION > /dev/null
    
    echo -e "${GREEN}✓ Launch template created: $LAUNCH_TEMPLATE_NAME${NC}"
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Step 4: Creating Auto Scaling Group${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Check if ASG exists
EXISTING_ASG=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query 'AutoScalingGroups[0].AutoScalingGroupName' \
  --output text \
  --region $REGION 2>/dev/null || echo "None")

if [ "$EXISTING_ASG" != "None" ]; then
    echo -e "${YELLOW}⚠ Auto Scaling Group already exists${NC}"
    echo "Updating configuration..."
    
    aws autoscaling update-auto-scaling-group \
      --auto-scaling-group-name "$ASG_NAME" \
      --launch-template "LaunchTemplateName=$LAUNCH_TEMPLATE_NAME" \
      --min-size $MIN_SIZE \
      --max-size $MAX_SIZE \
      --desired-capacity $DESIRED_SIZE \
      --region $REGION
    
    echo -e "${GREEN}✓ Auto Scaling Group updated${NC}"
else
    echo "Creating Auto Scaling Group..."
    
    aws autoscaling create-auto-scaling-group \
      --auto-scaling-group-name "$ASG_NAME" \
      --launch-template "LaunchTemplateName=$LAUNCH_TEMPLATE_NAME,Version=\$Latest" \
      --min-size $MIN_SIZE \
      --max-size $MAX_SIZE \
      --desired-capacity $DESIRED_SIZE \
      --vpc-zone-identifier "$SUBNET_IDS" \
      --health-check-type EC2 \
      --health-check-grace-period 300 \
      --tags "Key=Name,Value=AI-AutoScaled-Instance,PropagateAtLaunch=true" \
           "Key=ManagedBy,Value=AI-AutoScaler,PropagateAtLaunch=true" \
      --region $REGION
    
    echo -e "${GREEN}✓ Auto Scaling Group created: $ASG_NAME${NC}"
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Step 5: Creating Scaling Policies (Optional)${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo "Creating target tracking scaling policy (CPU-based)..."

aws autoscaling put-scaling-policy \
  --auto-scaling-group-name "$ASG_NAME" \
  --policy-name "target-tracking-cpu-policy" \
  --policy-type "TargetTrackingScaling" \
  --target-tracking-configuration '{
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ASGAverageCPUUtilization"
    },
    "TargetValue": 70.0
  }' \
  --region $REGION > /dev/null

echo -e "${GREEN}✓ Scaling policy created (target: 70% CPU)${NC}"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✓ Auto Scaling Group Setup Complete!                           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${BLUE}ASG Details:${NC}"
echo "  Name: $ASG_NAME"
echo "  Launch Template: $LAUNCH_TEMPLATE_NAME"
echo "  Instance Type: $INSTANCE_TYPE"
echo "  Min/Desired/Max: $MIN_SIZE/$DESIRED_SIZE/$MAX_SIZE"
echo "  VPC: $VPC_ID"
echo "  Subnets: $SUBNET_IDS"
echo "  Security Group: $SECURITY_GROUP_ID"
echo ""

echo -e "${BLUE}Instances will have:${NC}"
echo "  ✓ Docker installed"
echo "  ✓ Node Exporter (port 9100) for Prometheus"
echo "  ✓ CloudWatch monitoring enabled"
echo "  ✓ Simple web server on port 80"
echo ""

# Check ASG status
echo -e "${YELLOW}Checking ASG status...${NC}"
sleep 3

ASG_STATUS=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --region $REGION \
  --query 'AutoScalingGroups[0].[DesiredCapacity,Instances[].InstanceId]' \
  --output text)

echo -e "${GREEN}✓ ASG Status:${NC}"
echo "$ASG_STATUS"

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Next Steps${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo "1. Verify instances are launching:"
echo -e "   ${CYAN}aws autoscaling describe-auto-scaling-groups \\${NC}"
echo -e "   ${CYAN}     --auto-scaling-group-names $ASG_NAME \\${NC}"
echo -e "   ${CYAN}     --region $REGION${NC}"
echo ""

echo "2. Check instance health (wait 2-3 minutes):"
echo -e "   ${CYAN}aws ec2 describe-instances \\${NC}"
echo -e "   ${CYAN}     --filters \"Name=tag:ManagedBy,Values=AI-AutoScaler\" \\${NC}"
echo -e "   ${CYAN}     --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]' \\${NC}"
echo -e "   ${CYAN}     --output table \\${NC}"
echo -e "   ${CYAN}     --region $REGION${NC}"
echo ""

echo "3. Test Lambda scaling:"
echo -e "   ${CYAN}curl -X POST https://820f4lix3j.execute-api.us-east-1.amazonaws.com/prod \\${NC}"
echo -e "   ${CYAN}     -H \"Content-Type: application/json\" \\${NC}"
echo -e "   ${CYAN}     -d '{\"action\":\"scale_up\",\"alert_type\":\"cpu\"}'${NC}"
echo ""

echo "4. Monitor scaling in CloudWatch:"
echo "   - Go to EC2 Console → Auto Scaling Groups"
echo "   - Select: $ASG_NAME"
echo "   - View: Activity & Monitoring tabs"
echo ""

echo -e "${GREEN}Your infrastructure is ready for AI-powered auto-scaling! 🚀${NC}\n"