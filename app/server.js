const express = require('express');
const mongoose = require('mongoose');
const app = express();
const PORT = 3000;

// MongoDB connection string
const MONGO_URI = process.env.MONGO_URI || 'mongodb://mongo:27017/ecommerce';
let dbStatus = 'Connecting...';

// ================================================================
// MONGOOSE SCHEMA
// ================================================================
const productSchema = new mongoose.Schema({
  name: { type: String, required: true },
  price: { type: Number, required: true },
  image: { type: String, required: true }
}, { collection: 'products' });

const Product = mongoose.model('Product', productSchema);

// ================================================================
// FALLBACK DATA (used if MongoDB is not available)
// ================================================================
const fallbackProducts = [
  { name: 'Laptop', price: 1200, image: '💻' },
  { name: 'Phone', price: 800, image: '📱' },
  { name: 'Headphones', price: 150, image: '🎧' },
  { name: 'Tablet', price: 450, image: '📲' }
];

// ================================================================
// CONNECT TO MONGODB + SEED DATA
// ================================================================
async function connectDB() {
  try {
    await mongoose.connect(MONGO_URI, {
      serverSelectionTimeoutMS: 5000,
      connectTimeoutMS: 5000
    });
    dbStatus = 'Connected';
    console.log('✅ MongoDB connected successfully');

    // Seed products if collection is empty
    const count = await Product.countDocuments();
    if (count === 0) {
      await Product.insertMany(fallbackProducts);
      console.log('🌱 Products seeded to MongoDB');
    } else {
      console.log(`📦 Found ${count} products in MongoDB`);
    }
  } catch (err) {
    dbStatus = 'Offline (using fallback)';
    console.log('⚠️ MongoDB not ready:', err.message);
    console.log('📦 Using fallback product data');
  }
}

connectDB();

// ================================================================
// ROUTES
// ================================================================

// Health check (used by ALB)
app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

// API: Get all products from MongoDB
app.get('/api/products', async (req, res) => {
  try {
    if (dbStatus === 'Connected') {
      const products = await Product.find().lean();
      return res.json(products);
    }
    throw new Error('Database not connected');
  } catch (err) {
    res.json(fallbackProducts);
  }
});

// Home page — E-Commerce Store
app.get('/', async (req, res) => {
  let products = fallbackProducts;

  // Try to get real data from MongoDB
  try {
    if (dbStatus === 'Connected') {
      products = await Product.find().lean();
    }
  } catch (err) {
    console.log('Using fallback data for homepage');
  }

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
        <p>DevOps CI/CD Lab — Powered by Terraform + Ansible + Docker + MongoDB</p>
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
  console.log(`🚀 E-commerce app running on port ${PORT}`);
});
