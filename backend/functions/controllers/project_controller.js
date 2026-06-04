const admin = require('firebase-admin');
const db = admin.firestore();

exports.getProjects = async (req, res) => {
  try {
    const projectsRef = db.collection('users').doc(req.user.uid).collection('projects');
    const snapshot = await projectsRef.orderBy('createdAt', 'desc').get();
    const projects = [];
    snapshot.forEach(doc => projects.push({ id: doc.id, ...doc.data() }));
    res.json(projects);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.createProject = async (req, res) => {
  try {
    const projectData = { ...req.body, createdAt: admin.firestore.FieldValue.serverTimestamp() };
    const projectRef = await db.collection('users').doc(req.user.uid).collection('projects').add(projectData);
    res.status(201).json({ id: projectRef.id, message: 'Project created successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
