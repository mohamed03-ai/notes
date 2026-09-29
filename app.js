const express = require('express');
const path = require('path');

const app = express();
app.use(express.json({ limit: '10kb' }));
app.use(express.static(path.join(__dirname, 'public')));

// In-memory storage (resets when the pod restarts)
const notes = [];
let nextId = 1;

app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

app.get('/api/notes', (req, res) => {
  res.json(notes);
});

app.post('/api/notes', (req, res) => {
  const text = req.body && typeof req.body.text === 'string' ? req.body.text.trim() : '';
  if (!text) {
    return res.status(400).json({ error: 'Note text is required' });
  }
  if (text.length > 200) {
    return res.status(400).json({ error: 'Note text too long (max 200)' });
  }
  const note = { id: nextId++, text };
  notes.push(note);
  res.status(201).json(note);
});

module.exports = app;