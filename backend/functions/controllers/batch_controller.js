const admin = require('firebase-admin');
const db = admin.firestore();

exports.getBatches = async (req, res) => {
  try {
    const batchesRef = db.collection('users').doc(req.user.uid).collection('batches');
    const snapshot = await batchesRef.orderBy('createdAt', 'desc').get();
    const batches = [];
    snapshot.forEach(doc => batches.push({ id: doc.id, ...doc.data() }));
    res.json(batches);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.createBatch = async (req, res) => {
  try {
    const batchData = { ...req.body, createdAt: admin.firestore.FieldValue.serverTimestamp() };
    const batchRef = await db.collection('users').doc(req.user.uid).collection('batches').add(batchData);
    res.status(201).json({ id: batchRef.id, message: 'Batch created successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
