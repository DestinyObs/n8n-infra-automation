const express = require('express');
const client = require('prom-client');

const app = express();
const PORT = process.env.PORT || 3000;

// Enable JSON parsing
app.use(express.json());

// Prometheus metrics setup
const register = new client.Registry();

// Default metrics (CPU, memory, etc.)
client.collectDefaultMetrics({ register });

// Custom metrics
const httpRequestCounter = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'status', 'path'],
  registers: [register]
});

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'status', 'path'],
  buckets: [0.1, 0.5, 1, 2, 5],
  registers: [register]
});

// Simulate variable load
let errorRate = 0;
let responseTime = 100;
let requestCount = 0;

// Middleware to track metrics
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestCounter.inc({
      method: req.method,
      status: res.statusCode,
      path: req.path
    });
    httpRequestDuration.observe({
      method: req.method,
      status: res.statusCode,
      path: req.path
    }, duration);
  });
  
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});

// Metrics endpoint for Prometheus
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Test endpoint that can simulate different scenarios
app.get('/api/test', async (req, res) => {
  requestCount++;
  
  // Simulate response time variability
  const delay = responseTime + Math.random() * 100;
  await new Promise(resolve => setTimeout(resolve, delay));
  
  // Simulate errors based on error rate
  if (Math.random() < errorRate) {
    const errorType = Math.random() < 0.5 ? 500 : 400;
    return res.status(errorType).json({
      error: errorType === 500 ? 'Internal Server Error' : 'Bad Request',
      timestamp: new Date().toISOString()
    });
  }
  
  res.json({
    message: 'Success',
    requestNumber: requestCount,
    timestamp: new Date().toISOString()
  });
});

// Endpoint to simulate CPU load
app.post('/api/simulate/cpu', (req, res) => {
  const { duration = 30000, intensity = 0.8 } = req.body;
  
  console.log(`🔥 Simulating CPU load: ${intensity * 100}% for ${duration}ms`);
  
  const endTime = Date.now() + duration;
  
  const cpuLoad = () => {
    while (Date.now() < endTime) {
      // Busy loop to consume CPU
      Math.sqrt(Math.random() * 1000000);
      
      // Small breaks based on intensity
      if (Math.random() > intensity) {
        setTimeout(() => {}, 10);
      }
    }
  };
  
  // Run CPU load in background
  setImmediate(cpuLoad);
  
  res.json({
    message: 'CPU load simulation started',
    duration,
    intensity,
    timestamp: new Date().toISOString()
  });
});

// Endpoint to simulate memory pressure
app.post('/api/simulate/memory', (req, res) => {
  const { sizeMB = 100, duration = 30000 } = req.body;
  
  console.log(`💾 Simulating memory allocation: ${sizeMB}MB for ${duration}ms`);
  
  // Allocate memory
  const arrays = [];
  const chunkSize = 1024 * 1024; // 1MB chunks
  
  for (let i = 0; i < sizeMB; i++) {
    arrays.push(new Array(chunkSize).fill(Math.random()));
  }
  
  // Hold memory for duration, then release
  setTimeout(() => {
    arrays.length = 0;
    console.log('💾 Memory released');
  }, duration);
  
  res.json({
    message: 'Memory pressure simulation started',
    sizeMB,
    duration,
    timestamp: new Date().toISOString()
  });
});

// Endpoint to simulate error rate
app.post('/api/simulate/errors', (req, res) => {
  const { rate = 0.2, duration = 30000 } = req.body;
  
  console.log(`❌ Simulating error rate: ${rate * 100}% for ${duration}ms`);
  
  errorRate = rate;
  
  setTimeout(() => {
    errorRate = 0;
    console.log('❌ Error simulation ended');
  }, duration);
  
  res.json({
    message: 'Error simulation started',
    rate,
    duration,
    timestamp: new Date().toISOString()
  });
});

// Endpoint to simulate slow responses
app.post('/api/simulate/latency', (req, res) => {
  const { delayMs = 2000, duration = 30000 } = req.body;
  
  console.log(`🐌 Simulating high latency: ${delayMs}ms for ${duration}ms`);
  
  responseTime = delayMs;
  
  setTimeout(() => {
    responseTime = 100;
    console.log('🐌 Latency simulation ended');
  }, duration);
  
  res.json({
    message: 'Latency simulation started',
    delayMs,
    duration,
    timestamp: new Date().toISOString()
  });
});

// Scaling endpoint (mock)
app.post('/api/scale', (req, res) => {
  const {
    action,
    alert_type,
    instance,
    environment,
    severity,
    metric_value,
    ai_confidence,
    ai_reasoning,
    timestamp
  } = req.body;
  
  console.log('\n🚀 ============ AUTO-SCALING TRIGGERED ============');
  console.log(`Action: ${action}`);
  console.log(`Alert: ${alert_type}`);
  console.log(`Instance: ${instance}`);
  console.log(`Environment: ${environment}`);
  console.log(`Severity: ${severity}`);
  console.log(`Metric Value: ${metric_value}`);
  console.log(`AI Confidence: ${ai_confidence}%`);
  console.log(`AI Reasoning: ${ai_reasoning}`);
  console.log(`Timestamp: ${timestamp}`);
  console.log('================================================\n');
  
  // Simulate scaling action
  res.json({
    success: true,
    message: 'Scaling action initiated',
    details: {
      action,
      alert_type,
      instance,
      newInstanceCount: 3,
      estimatedTime: '2-3 minutes',
      timestamp: new Date().toISOString()
    }
  });
});

// Status endpoint
app.get('/api/status', (req, res) => {
  res.json({
    server: 'running',
    requestCount,
    errorRate,
    responseTime,
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    timestamp: new Date().toISOString()
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`\n🚀 Mock Application Server Started`);
  console.log(`📊 Metrics: http://localhost:${PORT}/metrics`);
  console.log(`🏥 Health: http://localhost:${PORT}/health`);
  console.log(`📈 Status: http://localhost:${PORT}/api/status`);
  console.log(`\n🧪 Simulation Endpoints:`);
  console.log(`   POST /api/simulate/cpu - Simulate CPU load`);
  console.log(`   POST /api/simulate/memory - Simulate memory pressure`);
  console.log(`   POST /api/simulate/errors - Simulate error rate`);
  console.log(`   POST /api/simulate/latency - Simulate high latency`);
  console.log(`\n⚡ Ready to receive alerts!\n`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully...');
  process.exit(0);
});