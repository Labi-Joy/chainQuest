"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const helmet_1 = __importDefault(require("helmet"));
const compression_1 = __importDefault(require("compression"));
const morgan_1 = __importDefault(require("morgan"));
const dotenv_1 = __importDefault(require("dotenv"));
// Load environment variables
dotenv_1.default.config();
const app = (0, express_1.default)();
const PORT = process.env.PORT || 8000;
// Middleware
app.use((0, helmet_1.default)());
app.use((0, cors_1.default)({
    origin: process.env.CORS_ORIGIN || 'http://localhost:3000',
    credentials: true,
}));
app.use((0, compression_1.default)());
app.use(express_1.default.json());
app.use(express_1.default.urlencoded({ extended: true }));
// Logging
if (process.env.NODE_ENV !== 'test') {
    app.use((0, morgan_1.default)('combined'));
}
// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        environment: process.env.NODE_ENV || 'development',
    });
});
// API routes
app.get('/api/v1', (req, res) => {
    res.json({
        message: 'ChainQuest API Server',
        version: '1.0.0',
        status: 'running',
        timestamp: new Date().toISOString(),
    });
});
// Basic quest endpoints
app.get('/api/v1/quests', (req, res) => {
    res.json({
        quests: [],
        total: 0,
        message: 'Quests endpoint working',
    });
});
// Basic user endpoints
app.get('/api/v1/users', (req, res) => {
    res.json({
        users: [],
        total: 0,
        message: 'Users endpoint working',
    });
});
// Basic auth endpoints
app.post('/api/v1/auth/login', (req, res) => {
    res.json({
        message: 'Auth endpoint working',
        token: 'mock-jwt-token',
    });
});
// 404 handler
app.use('*', (req, res) => {
    res.status(404).json({
        error: 'Not Found',
        message: `Can't find ${req.originalUrl} on this server!`,
    });
});
// Error handler
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({
        error: 'Internal Server Error',
        message: 'Something went wrong!',
    });
});
// Start server
app.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`📚 Environment: ${process.env.NODE_ENV || 'development'}`);
});
exports.default = app;
