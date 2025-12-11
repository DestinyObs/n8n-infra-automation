"""
AWS Lambda Function for Auto-Scaling
Handles scaling decisions from AI incident detection system
"""

import json
import boto3
import os
from datetime import datetime

# Initialize AWS clients
autoscaling = boto3.client('autoscaling')
ec2 = boto3.client('ec2')
cloudwatch = boto3.client('cloudwatch')

# Configuration from environment variables
AUTO_SCALING_GROUP_NAME = os.environ.get('AUTO_SCALING_GROUP_NAME', 'production-asg')
MIN_CAPACITY = int(os.environ.get('MIN_CAPACITY', '2'))
MAX_CAPACITY = int(os.environ.get('MAX_CAPACITY', '10'))
SCALE_UP_INCREMENT = int(os.environ.get('SCALE_UP_INCREMENT', '2'))
SCALE_DOWN_INCREMENT = int(os.environ.get('SCALE_DOWN_INCREMENT', '1'))

def lambda_handler(event, context):
    """
    Main Lambda handler for auto-scaling decisions
    
    Expected event format:
    {
        "action": "scale_up" | "scale_down" | "analyze",
        "alert_type": "cpu" | "memory" | "http_5xx" | "latency",
        "instance": "server-name",
        "severity": "warning" | "critical",
        "metric_value": "85%",
        "ai_confidence": 85,
        "ai_reasoning": "Sustained CPU load indicates traffic growth"
    }
    """
    
    try:
        print(f"Received event: {json.dumps(event)}")
        
        # Parse request
        action = event.get('action', 'analyze')
        alert_type = event.get('alert_type', 'unknown')
        severity = event.get('severity', 'warning')
        ai_confidence = event.get('ai_confidence', 0)
        
        # Get current ASG state
        asg_info = get_asg_info()
        current_capacity = asg_info['desired_capacity']
        current_instances = asg_info['instance_count']
        
        print(f"Current ASG state - Desired: {current_capacity}, Running: {current_instances}")
        
        # Determine scaling action
        if action == 'scale_up':
            result = scale_up(asg_info, alert_type, severity, ai_confidence)
        elif action == 'scale_down':
            result = scale_down(asg_info)
        else:
            result = {
                'action': 'no_change',
                'message': 'Analysis only, no scaling action taken',
                'current_capacity': current_capacity
            }
        
        # Log to CloudWatch
        log_scaling_event(action, alert_type, result)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'success': True,
                'timestamp': datetime.utcnow().isoformat(),
                'asg_name': AUTO_SCALING_GROUP_NAME,
                **result
            })
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'success': False,
                'error': str(e),
                'timestamp': datetime.utcnow().isoformat()
            })
        }

def get_asg_info():
    """Get current Auto Scaling Group information"""
    response = autoscaling.describe_auto_scaling_groups(
        AutoScalingGroupNames=[AUTO_SCALING_GROUP_NAME]
    )
    
    if not response['AutoScalingGroups']:
        raise Exception(f"Auto Scaling Group '{AUTO_SCALING_GROUP_NAME}' not found")
    
    asg = response['AutoScalingGroups'][0]
    
    return {
        'name': asg['AutoScalingGroupName'],
        'desired_capacity': asg['DesiredCapacity'],
        'min_size': asg['MinSize'],
        'max_size': asg['MaxSize'],
        'instance_count': len(asg['Instances']),
        'instances': asg['Instances'],
        'health_status': [i['HealthStatus'] for i in asg['Instances']]
    }

def scale_up(asg_info, alert_type, severity, ai_confidence):
    """Scale up the Auto Scaling Group"""
    current_capacity = asg_info['desired_capacity']
    
    # Calculate new capacity based on severity and AI confidence
    if severity == 'critical' or ai_confidence > 90:
        increment = SCALE_UP_INCREMENT * 2  # Aggressive scaling
    else:
        increment = SCALE_UP_INCREMENT
    
    new_capacity = min(current_capacity + increment, MAX_CAPACITY)
    
    if new_capacity == current_capacity:
        return {
            'action': 'no_change',
            'message': f'Already at maximum capacity ({MAX_CAPACITY})',
            'current_capacity': current_capacity,
            'max_capacity': MAX_CAPACITY
        }
    
    # Execute scaling
    print(f"Scaling UP: {current_capacity} -> {new_capacity}")
    
    autoscaling.set_desired_capacity(
        AutoScalingGroupName=AUTO_SCALING_GROUP_NAME,
        DesiredCapacity=new_capacity,
        HonorCooldown=False  # Override cooldown for critical alerts
    )
    
    return {
        'action': 'scaled_up',
        'message': f'Scaled from {current_capacity} to {new_capacity} instances',
        'previous_capacity': current_capacity,
        'new_capacity': new_capacity,
        'increment': increment,
        'reason': f'{severity} {alert_type} alert with {ai_confidence}% AI confidence',
        'estimated_ready_time': '2-5 minutes'
    }

def scale_down(asg_info):
    """Scale down the Auto Scaling Group"""
    current_capacity = asg_info['desired_capacity']
    new_capacity = max(current_capacity - SCALE_DOWN_INCREMENT, MIN_CAPACITY)
    
    if new_capacity == current_capacity:
        return {
            'action': 'no_change',
            'message': f'Already at minimum capacity ({MIN_CAPACITY})',
            'current_capacity': current_capacity,
            'min_capacity': MIN_CAPACITY
        }
    
    # Execute scaling
    print(f"Scaling DOWN: {current_capacity} -> {new_capacity}")
    
    autoscaling.set_desired_capacity(
        AutoScalingGroupName=AUTO_SCALING_GROUP_NAME,
        DesiredCapacity=new_capacity,
        HonorCooldown=True  # Respect cooldown for scale-down
    )
    
    return {
        'action': 'scaled_down',
        'message': f'Scaled from {current_capacity} to {new_capacity} instances',
        'previous_capacity': current_capacity,
        'new_capacity': new_capacity,
        'decrement': SCALE_DOWN_INCREMENT,
        'reason': 'Load decreased, scaling down to save costs'
    }

def log_scaling_event(action, alert_type, result):
    """Log scaling event to CloudWatch Metrics"""
    try:
        cloudwatch.put_metric_data(
            Namespace='AIIncidentDetection',
            MetricData=[
                {
                    'MetricName': 'ScalingAction',
                    'Timestamp': datetime.utcnow(),
                    'Value': 1,
                    'Unit': 'Count',
                    'Dimensions': [
                        {'Name': 'Action', 'Value': action},
                        {'Name': 'AlertType', 'Value': alert_type},
                        {'Name': 'ASG', 'Value': AUTO_SCALING_GROUP_NAME}
                    ]
                }
            ]
        )
    except Exception as e:
        print(f"Failed to log to CloudWatch: {str(e)}")

# Test function for local development
if __name__ == "__main__":
    # Test event
    test_event = {
        'action': 'scale_up',
        'alert_type': 'cpu',
        'severity': 'critical',
        'metric_value': '92%',
        'ai_confidence': 95,
        'ai_reasoning': 'Sustained CPU load indicates traffic growth'
    }
    
    result = lambda_handler(test_event, None)
    print(json.dumps(result, indent=2))