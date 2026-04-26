const express = require('express');
const mysql = require('mysql');

const app = express();
const port = process.env.APP_PORT || 3000;
const serverName = process.env.APP_NAME || 'Unknown Server';

// MySQL Connection
const connection = mysql.createConnection({
  host: process.env.MYSQL_HOST || 'localhost',
  user: process.env.MYSQL_USER || 'root',
  password: process.env.MYSQL_PASSWORD || 'secret',
  database: process.env.MYSQL_DB || 'appdb'
});

connection.connect((err) => {
  if (err) {
    console.error('MySQL Connection Error:', err);
    setTimeout(() => connection.connect(), 2000);
  } else {
    console.log(`[${serverName}] Connected to MySQL`);
  }
});

// Routes
app.get('/', (req, res) => {
  res.json({
    message: `Hello from ${serverName}`,
    timestamp: new Date().toISOString(),
    port: port,
    url: req.url
  });
});

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    server: serverName,
    port: port
  });
});

// Start Server
app.listen(port, () => {
  console.log(`\n🚀 ${serverName} running on port ${port}`);
  console.log(`📍 IP: 10.24.50.175:${port}`);
  console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`);
});