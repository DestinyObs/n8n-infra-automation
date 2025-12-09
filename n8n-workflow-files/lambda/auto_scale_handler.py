"""
AWS Lambda Function for Auto-Scaling EC2 Instances
Triggered by n8n workflow based on AI analysis
"""

import json
import boto3
import os
from datetime import datetime, timedelta
from typing import Dict, Any, List

# Initialize AWS clients
ec2 = boto3.client('ec2')
autoscaling = boto3.client('autoscaling')
cloudwatch = boto3.client('cloudwatch')

# Environment variables
ASG_NAME = os.environ.get('ASG_NAME', 'production-asg')
MIN_INSTANCES = int(os.environ.get('MIN_INSTANCES', 2))
MAX_INSTANCES = int(os.environ.get('MAX_INSTANCES', 10))
SCALE_UP_AMOUNT = int(os.environ.get('SCALE_UP_AMOUNT', 2))
COOLDOWN_PERIOD = int(os.environ.get('COOLDOWN_PERIOD', 300))  # seconds
REGION = os.environ.get('AWS_REGION', 'us-east-1')


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for auto-scaling operations
    
    Args:
        event: Event data from n8n containing alert information
        context: Lambda context object
        
    Returns:
        Response dict with status and details
    """
    
    print(f"Received event: {json.dumps(event)}")
    
    try:
        # Parse incoming event
        body = parse_event(event)
        
        alert_type = body.get('alert_type', 'unknown')
        instance = body.get('instance', 'unknown')
        metric_value = body.get('metric_value', 0)
        ai_confidence = body.get('ai_confidence', 'unknown')
        action = body.get('action', 'scale_up')
        
        print(f"Processing {action} request for {alert_type} alert")
        print(f"Instance: {instance}, Metric: {metric_value}, AI Confidence: {ai_confidence}")
        
        # Check if we're in cooldown period
        if is_in_cooldown(ASG_NAME):
            return create_response(
                200,
                {
                    'message': 'Scaling action skipped - in cooldown period',
                    'alert_type': alert_type,
                    'cooldown_remaining': get_cooldown_remaining(ASG_NAME)
                }
            )
        
        # Get current ASG status
        asg_info = get_asg_info(ASG_NAME)
        current_capacity = asg_info['desired_capacity']
        current_instances = asg_info['current_instances']
        
        print(f"Current ASG - Desired: {current_capacity}, Running: {current_instances}")
        
        # Execute scaling action
        if action == 'scale_up':
            return handle_scale_up(
                asg_name=ASG_NAME,
                current_capacity=current_capacity,
                alert_type=alert_type,
                metric_value=metric_value,
                ai_confidence=ai_confidence
            )
        
        elif action == 'scale_down':
            return handle_scale_down(
                asg_name=ASG_NAME,
                current_capacity=current_capacity,
                alert_type=alert_type
            )
        
        else:
            return create_response(400, {'error': f'Unknown action: {action}'})
    
    except Exception as e:
        print(f"Error in lambda_handler: {str(e)}")
        import traceback
        traceback.print_exc()
        
        return create_response(
            500,
            {
                'error': 'Internal server error',
                'message': str(e),
                'alert_sent_to_ops': True
            }
        )


def parse_event(event: Dict[str, Any]) -> Dict[str, Any]:
    """Parse incoming event from API Gateway or direct invocation"""
    if 'body' in event:
        # From API Gateway
        body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
    else:
        # Direct invocation
        body = event
    
    return body


def get_asg_info(asg_name: str) -> Dict[str, Any]:
    """Get current Auto Scaling Group information"""
    response = autoscaling.describe_auto_scaling_groups(
        AutoScalingGroupNames=[asg_name]
    )
    
    if not response['AutoScalingGroups']:
        raise ValueError(f'ASG {asg_name} not found')
    
    asg = response['AutoScalingGroups'][0]
    
    return {
        'desired_capacity': asg['DesiredCapacity'],
        'min_size': asg['MinSize'],
        'max_size': asg['MaxSize'],
        'current_instances': len(asg['Instances']),
        'instances': asg['Instances']
    }


def is_in_cooldown(asg_name: str) -> bool:
    """Check if ASG is in cooldown period"""
    try:
        response = autoscaling.describe_scaling_activities(
            AutoScalingGroupName=asg_name,
            MaxRecords=1
        )
        
        if response['Activities']:
            last_activity = response['Activities'][0]
            activity_time = last_activity['StartTime']
            
            # Check if within cooldown period
            cooldown_end = activity_time + timedelta(seconds=COOLDOWN_PERIOD)
            return datetime.now(activity_time.tzinfo) < cooldown_end
        
        return False
    
    except Exception as e:
        print(f"Error checking cooldown: {str(e)}")
        return False


def get_cooldown_remaining(asg_name: str) -> int:
    """Get remaining cooldown time in seconds"""
    try:
        response = autoscaling.describe_scaling_activities(
            AutoScalingGroupName=asg_name,
            MaxRecords=1
        )
        
        if response['Activities']:
            last_activity = response['Activities'][0]
            activity_time = last_activity['StartTime']
            cooldown_end = activity_time + timedelta(seconds=COOLDOWN_PERIOD)
            remaining = (cooldown_end - datetime.now(activity_time.tzinfo)).total_seconds()
            return max(0, int(remaining))
        
        return 0
    
    except Exception as e:
        print(f"Error getting cooldown remaining: {str(e)}")
        return 0


def handle_scale_up(
    asg_name: str,
    current_capacity: int,
    alert_type: str,
    metric_value: float,
    ai_confidence: str
) -> Dict[str, Any]:
    """Handle scale-up operation"""
    
    # Calculate new capacity
    new_capacity = min(current_capacity + SCALE_UP_AMOUNT, MAX_INSTANCES)
    
    if new_capacity <= current_capacity:
        message = f'Already at maximum capacity ({MAX_INSTANCES} instances)'
        print(message)
        
        # Send metric even if at max capacity
        send_scaling_metric(asg_name, alert_type, 'scale_up_rejected', 0)
        
        return create_response(
            200,
            {
                'message': message,
                'current_capacity': current_capacity,
                'max_capacity': MAX_INSTANCES,
                'recommendation': 'Consider increasing MAX_INSTANCES limit'
            }
        )
    
    # Perform scaling
    print(f"Scaling up from {current_capacity} to {new_capacity}")
    
    autoscaling.set_desired_capacity(
        AutoScalingGroupName=asg_name,
        DesiredCapacity=new_capacity,
        HonorCooldown=False  # Override cooldown for critical alerts
    )
    
    # Send metrics to CloudWatch
    send_scaling_metric(asg_name, alert_type, 'scale_up', new_capacity - current_capacity)
    
    # Tag new instances (will be applied when they launch)
    tag_specification = [
        {
            'ResourceType': 'instance',
            'Tags': [
                {'Key': 'ScaledBy', 'Value': 'n8n-ai-automation'},
                {'Key': 'ScalingReason', 'Value': alert_type},
                {'Key': 'AIConfidence', 'Value': ai_confidence},
                {'Key': 'ScaledAt', 'Value': datetime.now().isoformat()}
            ]
        }
    ]
    
    message = f'Successfully scaled up from {current_capacity} to {new_capacity} instances'
    print(message)
    
    return create_response(
        200,
        {
            'success': True,
            'message': message,
            'previous_capacity': current_capacity,
            'new_capacity': new_capacity,
            'instances_added': new_capacity - current_capacity,
            'alert_type': alert_type,
            'metric_value': metric_value,
            'ai_confidence': ai_confidence,
            'timestamp': datetime.now().isoformat(),
            'estimated_ready_time': '3-5 minutes'
        }
    )


def handle_scale_down(
    asg_name: str,
    current_capacity: int,
    alert_type: str
) -> Dict[str, Any]:
    """Handle scale-down operation"""
    
    new_capacity = max(current_capacity - 1, MIN_INSTANCES)
    
    if new_capacity >= current_capacity:
        message = f'Already at minimum capacity ({MIN_INSTANCES} instances)'
        print(message)
        
        return create_response(
            200,
            {
                'message': message,
                'current_capacity': current_capacity,
                'min_capacity': MIN_INSTANCES
            }
        )
    
    print(f"Scaling down from {current_capacity} to {new_capacity}")
    
    autoscaling.set_desired_capacity(
        AutoScalingGroupName=asg_name,
        DesiredCapacity=new_capacity,
        HonorCooldown=True  # Respect cooldown for scale-down
    )
    
    # Send metrics
    send_scaling_metric(asg_name, alert_type, 'scale_down', current_capacity - new_capacity)
    
    message = f'Successfully scaled down from {current_capacity} to {new_capacity} instances'
    print(message)
    
    return create_response(
        200,
        {
            'success': True,
            'message': message,
            'previous_capacity': current_capacity,
            'new_capacity': new_capacity,
            'instances_removed': current_capacity - new_capacity,
            'timestamp': datetime.now().isoformat()
        }
    )


def send_scaling_metric(
    asg_name: str,
    alert_type: str,
    action: str,
    capacity_change: int
):
    """Send custom metrics to CloudWatch"""
    try:
        cloudwatch.put_metric_data(
            Namespace='CustomMetrics/AutoScaling',
            MetricData=[
                {
                    'MetricName': 'ScalingActivities',
                    'Value': 1,
                    'Unit': 'Count',
                    'Timestamp': datetime.now(),
                    'Dimensions': [
                        {'Name': 'AutoScalingGroupName', 'Value': asg_name},
                        {'Name': 'AlertType', 'Value': alert_type},
                        {'Name': 'Action', 'Value': action}
                    ]
                },
                {
                    'MetricName': 'CapacityChange',
                    'Value': capacity_change,
                    'Unit': 'Count',
                    'Timestamp': datetime.now(),
                    'Dimensions': [
                        {'Name': 'AutoScalingGroupName', 'Value': asg_name},
                        {'Name': 'Action', 'Value': action}
                    ]
                }
            ]
        )
        print(f"Sent scaling metrics to CloudWatch")
    
    except Exception as e:
        print(f"Error sending metrics: {str(e)}")


def create_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    """Create standardized API Gateway response"""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(body, default=str)
    }


def get_instance_health(instance_id: str) -> bool:
    """Check if an EC2 instance is healthy"""
    try:
        response = ec2.describe_instance_status(InstanceIds=[instance_id])
        
        if response['InstanceStatuses']:
            status = response['InstanceStatuses'][0]
            return (
                status['InstanceState']['Name'] == 'running' and
                status['InstanceStatus']['Status'] == 'ok' and
                status['SystemStatus']['Status'] == 'ok'
            )
        
        return False
    
    except Exception as e:
        print(f"Error checking instance health: {str(e)}")
        return False


def get_unhealthy_instances(asg_name: str) -> List[str]:
    """Get list of unhealthy instances in ASG"""
    unhealthy = []
    
    try:
        asg_info = get_asg_info(asg_name)
        
        for instance in asg_info['instances']:
            instance_id = instance['InstanceId']
            if not get_instance_health(instance_id):
                unhealthy.append(instance_id)
        
        return unhealthy
    
    except Exception as e:
        print(f"Error getting unhealthy instances: {str(e)}")
        return []