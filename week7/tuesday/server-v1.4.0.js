#!/usr/bin/env node

const http = require('http');
const PORT = process.env.PORT || 3001;
const APP_VERSION = process.env.APP_VERSION || 'v1.4.0';

const server = http.createServer((req, res) => {
    res.setHeader('Content-Type', 'application/json');
    
    if (req.url === '/health') {
        const response = {
            status: 'ok',
            version: APP_VERSION,
            port: PORT,
            timestamp: new Date().toISOString(),
            uptime: process.uptime(),
            features: ['improved-performance', 'better-error-handling']  // v1.4.0 additions
        };
        res.writeHead(200);
        res.end(JSON.stringify(response, null, 2));
    } else if (req.url === '/') {
        res.writeHead(200);
        res.end(JSON.stringify({
            message: 'KijaniKiosk API Service',
            version: APP_VERSION,
            port: PORT
        }, null, 2));
    } else {
        res.writeHead(404);
        res.end(JSON.stringify({ error: 'Not found' }));
    }
});

server.listen(PORT, '127.0.0.1', () => {
    console.log(`[${new Date().toISOString()}] KijaniKiosk API ${APP_VERSION} listening on port ${PORT}`);
    console.log(`[${new Date().toISOString()}] Health endpoint: http://127.0.0.1:${PORT}/health`);
});

process.on('SIGTERM', () => {
    console.log(`[${new Date().toISOString()}] SIGTERM received, shutting down gracefully...`);
    server.close(() => {
        console.log(`[${new Date().toISOString()}] Server closed`);
        process.exit(0);
    });
});

process.on('SIGINT', () => {
    console.log(`[${new Date().toISOString()}] SIGINT received, shutting down gracefully...`);
    server.close(() => {
        console.log(`[${new Date().toISOString()}] Server closed`);
        process.exit(0);
    });
});
