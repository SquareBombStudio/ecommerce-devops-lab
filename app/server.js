const express = require('express');
const mongoose = require('mongoose');
const app = express();
const PORT = 3000;

// Connect to MongoDB (if available)
const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/ecommerce';
let dbStatus = 'Connecting...';

mongoose.connect(MONGO_URI)
  .then(() => { dbStatus = 'Connected'; console.log('MongoDB connected'); })
  .catch(err => { dbStatus = 'Offline (using fallback)'; console.log('MongoDB not ready, using fallback data'); });

// Sample product data (fallback if DB is down)
const products = [
  { name: 'Laptop', price: 1200, image: '💻' },
  { name: 'Phone', price: 800, image: '📱' },
  { name: 'Headphones', price: 150, image: '🎧' },
  { name: 'Tablet', price: 450, image: '📲' }
];

// Health check endpoint (used by ALB)
app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

// API endpoint for products
app.get('/api/products', (req, res) => {
  res.json(products);
});

// Main page - E-Commerce Store
app.get('/', (req, res) => {
  const productCards = products.map(p => `
    <div style="border:1px solid #ddd; border-radius:8px; padding:20px; margin:10px; width:200px; text-align:center; display:inline-block; background:#fff;">
      <div style="font-size:48px; margin-bottom:10px;">${p.image}</div>
      <h3 style="margin:5px 0; color:#333;">${p.name}</h3>
      <p style="font-size:20px; color:#2ecc71; font-weight:bold;">$${p.price}</p>
      <button style="background:#3498db; color:white; border:none; padding:10px 20px; border-radius:5px; cursor:pointer;">Add to Cart</button>
    </div>
  `).join('');

  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>E-Commerce Store</title>
      <style>
        body { font-family: Arial, sans-serif; background: #f5f6fa; margin: 0; padding: 0; }
        .header { background: #2c3e50; color: white; padding: 20px; text-align: center; }
        .container { max-width: 1000px; margin: 30px auto; text-align: center; }
        .subtitle { color: #7f8c8d; margin-bottom: 30px; }
        .status { background: #ecf0f1; padding: 10px; border-radius: 5px; margin-bottom: 20px; display: inline-block; }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>🛒 E-Commerce Store</h1>
        <p>DevOps CI/CD Lab - Powered by Terraform + Ansible + Docker</p>
      </div>
      <div class="container">
        <div class="status">🟢 Server: Online | 🗄️ Database: ${dbStatus}</div>
        <p class="subtitle">Hot Deals Today</p>
        ${productCards}
      </div>
    </body>
    </html>
  `);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`E-commerce app running on port ${PORT}`);
});
