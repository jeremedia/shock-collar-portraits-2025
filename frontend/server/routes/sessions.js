import { Router } from 'express';
import sessionManager from '../services/sessionManager.js';

const router = Router();

router.get('/', async (req, res) => {
  try {
    const sessions = await sessionManager.getSessions();
    res.json(sessions);
  } catch (error) {
    console.error('Error fetching sessions:', error);
    res.status(500).json({ error: 'Failed to fetch sessions' });
  }
});

router.get('/by-day', async (req, res) => {
  try {
    const sessionsByDay = await sessionManager.getSessionsByDay();
    res.json(sessionsByDay);
  } catch (error) {
    console.error('Error fetching sessions by day:', error);
    res.status(500).json({ error: 'Failed to fetch sessions' });
  }
});

router.get('/:sessionId', async (req, res) => {
  try {
    const session = await sessionManager.getSession(req.params.sessionId);
    res.json(session);
  } catch (error) {
    console.error('Error fetching session:', error);
    res.status(404).json({ error: 'Session not found' });
  }
});

router.get('/:sessionId/adjacent', async (req, res) => {
  try {
    const adjacent = await sessionManager.findAdjacentSessions(req.params.sessionId);
    res.json(adjacent);
  } catch (error) {
    console.error('Error finding adjacent sessions:', error);
    res.status(500).json({ error: 'Failed to find adjacent sessions' });
  }
});

export default router;