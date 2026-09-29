const request = require('supertest');
const app = require('../app');

describe('Notes API', () => {
  test('GET /health returns OK', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.text).toBe('OK');
  });

  test('POST /api/notes adds a note', async () => {
    const res = await request(app).post('/api/notes').send({ text: 'Learn DevSecOps' });
    expect(res.status).toBe(201);
    expect(res.body.text).toBe('Learn DevSecOps');

    const list = await request(app).get('/api/notes');
    expect(list.body.length).toBe(1);
  });

  test('POST /api/notes rejects an empty note', async () => {
    const res = await request(app).post('/api/notes').send({ text: '   ' });
    expect(res.status).toBe(400);
  });
});