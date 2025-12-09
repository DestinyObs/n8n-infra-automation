#!/usr/bin/env python3
"""
HTTP Error Generator - Simulate 5xx and 4xx errors for testing
"""

from flask import Flask, jsonify, request
import random
import time
from datetime import datetime
import threading

app = Flask(__name__)

# Statistics
stats = {
    'total_requests': 0,
    '2xx': 0,
    '4xx': 0,
    '5xx': 0,
    'start_time': datetime.now()
}

# Configuration
config = {
    'error_rate_5xx': 0.0,  # 0-1 (0% to 100%)
    'error_rate_4xx': 0.0,
    'response_delay': 0.0   # seconds
}


@app.route('/')
def index():
    """Main endpoint"""
    return jsonify({
        'status': 'running',
        'message': 'HTTP Error Generator',
        'endpoints': {
            '/api/test': 'Test endpoint with configurable error rates',
            '/api/always-500': 'Always returns 500 error',
            '/api/always-404': 'Always returns 404 error',
            '/config': 'View/update error configuration',
            '/stats': 'View request statistics',
            '/stress': 'Stress endpoint (configurable duration)',
            '/reset': 'Reset statistics'
        }
    })


@app.route('/api/test')
def test_endpoint():
    """Test endpoint with configurable error rates"""
    stats['total_requests'] += 1
    
    # Simulate delay if configured
    if config['response_delay'] > 0:
        time.sleep(config['response_delay'])
    
    # Check if we should return 5xx error
    if random.random() < config['error_rate_5xx']:
        stats['5xx'] += 1
        error_codes = [500, 502, 503, 504]
        status_code = random.choice(error_codes)
        return jsonify({
            'error': 'Internal Server Error',
            'message': f'Simulated {status_code} error',
            'timestamp': datetime.now().isoformat()
        }), status_code
    
    # Check if we should return 4xx error
    if random.random() < config['error_rate_4xx']:
        stats['4xx'] += 1
        error_codes = [400, 401, 403, 404, 429]
        status_code = random.choice(error_codes)
        return jsonify({
            'error': 'Client Error',
            'message': f'Simulated {status_code} error',
            'timestamp': datetime.now().isoformat()
        }), status_code
    
    # Return success
    stats['2xx'] += 1
    return jsonify({
        'status': 'success',
        'message': 'Request processed successfully',
        'timestamp': datetime.now().isoformat()
    }), 200


@app.route('/api/always-500')
def always_500():
    """Always returns 500 error"""
    stats['total_requests'] += 1
    stats['5xx'] += 1
    
    return jsonify({
        'error': 'Internal Server Error',
        'message': 'This endpoint always returns 500',
        'timestamp': datetime.now().isoformat()
    }), 500


@app.route('/api/always-404')
def always_404():
    """Always returns 404 error"""
    stats['total_requests'] += 1
    stats['4xx'] += 1
    
    return jsonify({
        'error': 'Not Found',
        'message': 'This endpoint always returns 404',
        'timestamp': datetime.now().isoformat()
    }), 404


@app.route('/stress')
def stress_endpoint():
    """Generate continuous errors for testing"""
    duration = int(request.args.get('duration', 60))  # seconds
    error_type = request.args.get('type', '5xx')  # 5xx or 4xx
    rate = int(request.args.get('rate', 10))  # errors per second
    
    stats['total_requests'] += 1
    
    def generate_errors():
        end_time = time.time() + duration
        count = 0
        
        while time.time() < end_time:
            # Make internal request to test endpoint
            for _ in range(rate):
                if error_type == '5xx':
                    stats['5xx'] += 1
                    count += 1
                else:
                    stats['4xx'] += 1
                    count += 1
            time.sleep(1)
        
        print(f"Stress test completed: {count} {error_type} errors generated")
    
    # Start stress test in background
    thread = threading.Thread(target=generate_errors)
    thread.daemon = True
    thread.start()
    
    return jsonify({
        'status': 'started',
        'message': f'Generating {error_type} errors',
        'duration': duration,
        'rate': f'{rate} errors/second',
        'total_errors': duration * rate
    }), 200


@app.route('/config', methods=['GET', 'POST'])
def configure():
    """View or update error configuration"""
    if request.method == 'POST':
        data = request.json
        
        if 'error_rate_5xx' in data:
            config['error_rate_5xx'] = float(data['error_rate_5xx'])
        
        if 'error_rate_4xx' in data:
            config['error_rate_4xx'] = float(data['error_rate_4xx'])
        
        if 'response_delay' in data:
            config['response_delay'] = float(data['response_delay'])
        
        return jsonify({
            'status': 'updated',
            'config': config
        })
    
    return jsonify(config)


@app.route('/stats')
def get_stats():
    """Get request statistics"""
    uptime = (datetime.now() - stats['start_time']).total_seconds()
    
    return jsonify({
        'stats': stats,
        'uptime_seconds': uptime,
        'requests_per_second': stats['total_requests'] / uptime if uptime > 0 else 0,
        'error_rates': {
            '2xx_rate': stats['2xx'] / stats['total_requests'] if stats['total_requests'] > 0 else 0,
            '4xx_rate': stats['4xx'] / stats['total_requests'] if stats['total_requests'] > 0 else 0,
            '5xx_rate': stats['5xx'] / stats['total_requests'] if stats['total_requests'] > 0 else 0
        }
    })


@app.route('/reset', methods=['POST'])
def reset_stats():
    """Reset statistics"""
    stats['total_requests'] = 0
    stats['2xx'] = 0
    stats['4xx'] = 0
    stats['5xx'] = 0
    stats['start_time'] = datetime.now()
    
    return jsonify({
        'status': 'reset',
        'message': 'Statistics reset successfully'
    })


if __name__ == '__main__':
    print("""
    ========================================
    HTTP Error Generator
    ========================================
    
    Endpoints:
    • GET  /                    - Service info
    • GET  /api/test           - Test endpoint (configurable errors)
    • GET  /api/always-500     - Always 500 error
    • GET  /api/always-404     - Always 404 error
    • GET  /stress             - Generate continuous errors
    • GET  /stats              - View statistics
    • POST /config             - Update error rates
    • POST /reset              - Reset statistics
    
    Examples:
    
    1. Configure error rates:
       curl -X POST http://localhost:8080/config \\
         -H "Content-Type: application/json" \\
         -d '{"error_rate_5xx": 0.3, "error_rate_4xx": 0.1}'
    
    2. Generate stress (100 5xx errors/sec for 60 seconds):
       curl "http://localhost:8080/stress?type=5xx&rate=100&duration=60"
    
    3. Load test with Apache Bench:
       ab -n 1000 -c 50 http://localhost:8080/api/test
    
    ========================================
    Starting server on http://0.0.0.0:8080
    ========================================
    """)
    
    app.run(host='0.0.0.0', port=8080, debug=False)