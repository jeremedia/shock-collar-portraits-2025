import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import photoIndexer from '../utils/photoIndexer.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

class SessionManager {
  constructor() {
    this.index = null;
    this.sessionsCache = new Map();
    this.baseDir = path.resolve(__dirname, '../../../');
  }

  async loadIndex() {
    if (this.index) {
      return this.index;
    }

    try {
      // Get index from photoIndexer (it will create it if it doesn't exist)
      this.index = await photoIndexer.getIndex();
      return this.index;
    } catch (error) {
      console.error('Error loading index:', error);
      throw error;
    }
  }

  async getSessions() {
    const index = await this.loadIndex();
    
    return index.sessions.map(session => ({
      id: session.id,
      sessionNumber: session.sessionNumber,
      timestamp: session.timestamp,
      dayOfWeek: session.dayOfWeek,
      source: session.source,
      type: session.type,
      photoCount: session.photoCount,
      duration: session.duration,
      heroIndex: session.heroIndex,
      heroPhoto: session.photos[session.heroIndex]?.filename,
      firstPhoto: session.photos[0]?.filename
    }));
  }

  async getSession(sessionId) {
    if (this.sessionsCache.has(sessionId)) {
      return this.sessionsCache.get(sessionId);
    }

    const index = await this.loadIndex();
    const session = index.sessions.find(s => s.id === sessionId);
    
    if (!session) {
      throw new Error(`Session ${sessionId} not found`);
    }

    // Enrich session data for frontend
    const enrichedSession = {
      ...session,
      photos: session.photos.map((photo, index) => ({
        ...photo,
        index,
        url: `/api/images/${sessionId}/${encodeURIComponent(photo.filename)}`
      }))
    };

    this.sessionsCache.set(sessionId, enrichedSession);
    return enrichedSession;
  }

  async getSessionsByDay() {
    const sessions = await this.getSessions();
    const byDay = {};
    
    sessions.forEach(session => {
      if (!byDay[session.dayOfWeek]) {
        byDay[session.dayOfWeek] = [];
      }
      byDay[session.dayOfWeek].push(session);
    });
    
    // Sort days in order
    const dayOrder = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
    const sortedDays = {};
    
    dayOrder.forEach(day => {
      if (byDay[day]) {
        sortedDays[day] = byDay[day];
      }
    });
    
    return sortedDays;
  }

  async findAdjacentSessions(sessionId) {
    const index = await this.loadIndex();
    const sessions = index.sessions;
    const currentIndex = sessions.findIndex(s => s.id === sessionId);
    
    if (currentIndex === -1) {
      return { prev: null, next: null };
    }
    
    return {
      prev: currentIndex > 0 ? sessions[currentIndex - 1].id : null,
      next: currentIndex < sessions.length - 1 ? sessions[currentIndex + 1].id : null
    };
  }

  async getPhotoPath(sessionId, filename) {
    const session = await this.getSession(sessionId);
    const photo = session.photos.find(p => p.filename === filename);
    
    if (!photo) {
      throw new Error(`Photo ${filename} not found in session ${sessionId}`);
    }
    
    return path.join(this.baseDir, photo.path);
  }

  async refreshIndex() {
    // Clear cache
    this.index = null;
    this.sessionsCache.clear();
    
    // Rebuild index
    await photoIndexer.refreshIndex();
    
    // Reload
    return await this.loadIndex();
  }

  async getStats() {
    const index = await this.loadIndex();
    return index.stats;
  }
}

export default new SessionManager();