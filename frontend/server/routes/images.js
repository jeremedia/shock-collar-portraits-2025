import { Router } from 'express';
import path from 'path';
import fs from 'fs/promises';
import imageProcessor from '../services/imageProcessor.js';
import sessionManager from '../services/sessionManager.js';

const router = Router();

// Serve image (original or processed)
router.get('/:sessionId/:filename', async (req, res) => {
  try {
    const { sessionId, filename } = req.params;
    const { size = 'original', format = 'original' } = req.query;
    
    // Get the actual file path from session manager
    const imagePath = await sessionManager.getPhotoPath(sessionId, decodeURIComponent(filename));
    
    // Check if file exists
    try {
      await fs.access(imagePath);
    } catch {
      return res.status(404).json({ error: 'Image file not found' });
    }
    
    // Serve original if requested
    if (size === 'original' && format === 'original') {
      // Set appropriate content type
      const ext = path.extname(filename).toLowerCase();
      const contentTypes = {
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.png': 'image/png',
        '.heic': 'image/heic',
        '.webp': 'image/webp'
      };
      
      res.set('Content-Type', contentTypes[ext] || 'application/octet-stream');
      res.set('Cache-Control', 'public, max-age=31536000'); // 1 year cache for originals
      res.sendFile(imagePath);
      return;
    }
    
    // Process the image
    try {
      const processedPath = await imageProcessor.processWithQueue(
        imagePath,
        size === 'original' ? 'large' : size,
        format === 'original' ? 'webp' : format
      );
      
      res.set('Cache-Control', 'public, max-age=31536000'); // 1 year cache
      res.set('Content-Type', format === 'webp' ? 'image/webp' : 'image/jpeg');
      res.sendFile(processedPath);
    } catch (error) {
      console.error('Error processing image:', error);
      // Fallback to original
      res.sendFile(imagePath);
    }
    
  } catch (error) {
    console.error('Error serving image:', error);
    res.status(500).json({ error: error.message || 'Failed to serve image' });
  }
});

// Get image metadata
router.get('/:sessionId/:filename/metadata', async (req, res) => {
  try {
    const { sessionId, filename } = req.params;
    
    const imagePath = await sessionManager.getPhotoPath(sessionId, decodeURIComponent(filename));
    const metadata = await imageProcessor.getImageMetadata(imagePath);
    
    if (!metadata) {
      return res.status(500).json({ error: 'Failed to get metadata' });
    }
    
    res.json(metadata);
    
  } catch (error) {
    console.error('Error fetching metadata:', error);
    res.status(500).json({ error: error.message || 'Failed to fetch metadata' });
  }
});

// Preload/batch process images
router.post('/preload', async (req, res) => {
  try {
    const { sessionId, photos, size = 'medium' } = req.body;
    
    if (!sessionId || !photos || !Array.isArray(photos)) {
      return res.status(400).json({ error: 'Invalid request' });
    }
    
    const results = [];
    
    // Limit to 20 photos for batch processing
    for (const filename of photos.slice(0, 20)) {
      try {
        const imagePath = await sessionManager.getPhotoPath(sessionId, filename);
        await imageProcessor.processWithQueue(imagePath, size, 'webp');
        results.push({ filename, status: 'cached' });
      } catch (error) {
        results.push({ filename, status: 'error', error: error.message });
      }
    }
    
    res.json({ results });
    
  } catch (error) {
    console.error('Error preloading images:', error);
    res.status(500).json({ error: error.message || 'Failed to preload images' });
  }
});

// Clean cache endpoint
router.post('/cache/clean', async (req, res) => {
  try {
    await imageProcessor.cleanCache();
    res.json({ success: true, message: 'Cache cleaned' });
  } catch (error) {
    console.error('Error cleaning cache:', error);
    res.status(500).json({ error: 'Failed to clean cache' });
  }
});

export default router;