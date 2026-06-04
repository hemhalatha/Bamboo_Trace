const functions = require('firebase-functions');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

const app = express();

// Middleware
app.use(cors({ origin: true }));
app.use(helmet());
app.use(express.json());

// Auth middleware to validate Firebase ID token
const authenticateUser = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    const idToken = authHeader.split('Bearer ')[1];
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    req.user = decodedToken;
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Unauthorized - invalid token' });
  }
};

app.use(authenticateUser);

// Example health check
app.get('/health', (req, res) => {
  res.json({ status: 'OK', message: 'BambooTrace API is running' });
});

// Get user's batches
app.get('/batches', async (req, res) => {
  try {
    const userBatchesRef = db.collection('users').doc(req.user.uid).collection('batches');
    const snapshot = await userBatchesRef.orderBy('createdAt', 'desc').get();
    let batches = [];
    snapshot.forEach(doc => {
      batches.push({ id: doc.id, ...doc.data() });
    });
    res.json(batches);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Add new batch
app.post('/batches', async (req, res) => {
  try {
    const batchData = { ...req.body, createdAt: admin.firestore.FieldValue.serverTimestamp() };
    const batchRef = await db.collection('users').doc(req.user.uid).collection('batches').add(batchData);
    res.status(201).json({ id: batchRef.id });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Similar routes for projects
app.get('/projects', async (req, res) => {
  try {
    const userProjectsRef = db.collection('users').doc(req.user.uid).collection('projects');
    const snapshot = await userProjectsRef.orderBy('createdAt', 'desc').get();
    let projects = [];
    snapshot.forEach(doc => projects.push({ id: doc.id, ...doc.data() }));
    res.json(projects);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/projects', async (req, res) => {
  try {
    const projectData = { ...req.body, createdAt: admin.firestore.FieldValue.serverTimestamp() };
    const projectRef = await db.collection('users').doc(req.user.uid).collection('projects').add(projectData);
    res.status(201).json({ id: projectRef.id });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Similar routes for orders
app.get('/orders', async (req, res) => {
  try {
    const userOrdersRef = db.collection('users').doc(req.user.uid).collection('orders');
    const snapshot = await userOrdersRef.orderBy('createdAt', 'desc').get();
    let orders = [];
    snapshot.forEach(doc => orders.push({ id: doc.id, ...doc.data() }));
    res.json(orders);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/orders', async (req, res) => {
  try {
    const orderData = { ...req.body, createdAt: admin.firestore.FieldValue.serverTimestamp() };
    const orderRef = await db.collection('users').doc(req.user.uid).collection('orders').add(orderData);
    res.status(201).json({ id: orderRef.id });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Export API as Firebase Cloud Function
exports.api = functions.https.onRequest(app);
