import { Router } from 'express';
import fs from 'fs/promises';
import path from 'path';
import config from '../config.js';

const router = Router();

const selectionsFile = path.join(
  path.dirname(config.cacheDir),
  'selections.json'
);

async function loadSelections() {
  try {
    const data = await fs.readFile(selectionsFile, 'utf-8');
    return JSON.parse(data);
  } catch {
    return {};
  }
}

async function saveSelections(selections) {
  await fs.writeFile(selectionsFile, JSON.stringify(selections, null, 2));
}

router.get('/', async (req, res) => {
  try {
    const selections = await loadSelections();
    res.json(selections);
  } catch (error) {
    console.error('Error loading selections:', error);
    res.status(500).json({ error: 'Failed to load selections' });
  }
});

router.get('/:sessionId', async (req, res) => {
  try {
    const selections = await loadSelections();
    const sessionSelection = selections[req.params.sessionId] || null;
    res.json({ selection: sessionSelection });
  } catch (error) {
    console.error('Error loading selection:', error);
    res.status(500).json({ error: 'Failed to load selection' });
  }
});

router.post('/:sessionId', async (req, res) => {
  try {
    const { photoIndex, filename } = req.body;
    
    if (typeof photoIndex !== 'number' || !filename) {
      return res.status(400).json({ error: 'Invalid selection data' });
    }
    
    const selections = await loadSelections();
    selections[req.params.sessionId] = {
      photoIndex,
      filename,
      timestamp: new Date().toISOString()
    };
    
    await saveSelections(selections);
    res.json({ success: true });
  } catch (error) {
    console.error('Error saving selection:', error);
    res.status(500).json({ error: 'Failed to save selection' });
  }
});

router.delete('/:sessionId', async (req, res) => {
  try {
    const selections = await loadSelections();
    delete selections[req.params.sessionId];
    await saveSelections(selections);
    res.json({ success: true });
  } catch (error) {
    console.error('Error deleting selection:', error);
    res.status(500).json({ error: 'Failed to delete selection' });
  }
});

router.post('/export', async (req, res) => {
  try {
    const selections = await loadSelections();
    const { format = 'json' } = req.body;
    
    if (format === 'csv') {
      const csv = ['SessionID,Filename,Timestamp'];
      for (const [sessionId, data] of Object.entries(selections)) {
        csv.push(`${sessionId},${data.filename},${data.timestamp}`);
      }
      res.type('text/csv');
      res.send(csv.join('\n'));
    } else {
      res.json(selections);
    }
  } catch (error) {
    console.error('Error exporting selections:', error);
    res.status(500).json({ error: 'Failed to export selections' });
  }
});

export default router;