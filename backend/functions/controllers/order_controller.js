const admin = require('firebase-admin');
const db = admin.firestore();

exports.getOrders = async (req, res) => {
  try {
    const ordersRef = db.collection('users').doc(req.user.uid).collection('orders');
    const snapshot = await ordersRef.orderBy('createdAt', 'desc').get();
    const orders = [];
    snapshot.forEach(doc => orders.push({ id: doc.id, ...doc.data() }));
    res.json(orders);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.createOrder = async (req, res) => {
  try {
    const orderData = { ...req.body, createdAt: admin.firestore.FieldValue.serverTimestamp() };
    const orderRef = await db.collection('users').doc(req.user.uid).collection('orders').add(orderData);
    res.status(201).json({ id: orderRef.id, message: 'Order created successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
