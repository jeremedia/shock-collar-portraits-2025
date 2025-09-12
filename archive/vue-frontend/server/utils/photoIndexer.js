import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import crypto from 'crypto';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

class PhotoIndexer {
  constructor() {
    this.baseDir = path.resolve(__dirname, '../../../');
    this.photoDirs = {
      canon: path.join(this.baseDir, 'card_download_1'),
      iphone: path.join(this.baseDir, 'iphone_sessions'),
      iphoneDayOne: path.join(this.baseDir, 'iphone_day_one_shots')
    };
    this.metadataFile = path.join(this.baseDir, 'photo_index.json');
    this.supportedFormats = /\.(jpg|jpeg|heic|png|cr3)$/i;
    this.imageFormats = /\.(jpg|jpeg|heic|png)$/i;
  }

  async indexAllPhotos() {
    console.log('Starting photo indexing...');
    const sessions = [];
    const photoMap = new Map();
    
    // Index Canon burst sessions
    if (await this.directoryExists(this.photoDirs.canon)) {
      const canonSessions = await this.indexCanonSessions();
      sessions.push(...canonSessions);
    }
    
    // Index iPhone sessions
    if (await this.directoryExists(this.photoDirs.iphone)) {
      const iphoneSessions = await this.indexIphoneSessions();
      sessions.push(...iphoneSessions);
    }
    
    // Index iPhone day one shots (if not already in sessions)
    if (await this.directoryExists(this.photoDirs.iphoneDayOne)) {
      const dayOneSession = await this.indexIphoneDayOne();
      if (dayOneSession) sessions.push(dayOneSession);
    }
    
    // Sort sessions by timestamp
    sessions.sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));
    
    // Calculate statistics
    const stats = this.calculateStats(sessions);
    
    const index = {
      version: '2.0',
      generated: new Date().toISOString(),
      stats,
      sessions
    };
    
    // Save index
    await fs.writeFile(this.metadataFile, JSON.stringify(index, null, 2));
    console.log(`Indexing complete: ${stats.totalSessions} sessions, ${stats.totalPhotos} photos`);
    
    return index;
  }

  async indexCanonSessions() {
    const sessions = [];
    const dirs = await fs.readdir(this.photoDirs.canon);
    
    for (const dir of dirs) {
      if (!dir.startsWith('burst_')) continue;
      
      const sessionPath = path.join(this.photoDirs.canon, dir);
      const stat = await fs.stat(sessionPath);
      
      if (!stat.isDirectory()) continue;
      
      const session = await this.processCanonSession(dir, sessionPath);
      if (session) sessions.push(session);
    }
    
    return sessions;
  }

  async processCanonSession(dirName, sessionPath) {
    const match = dirName.match(/burst_(\d+)_(\d{8})_(\d{6})/);
    if (!match) return null;
    
    const [, sessionNum, dateStr, timeStr] = match;
    const timestamp = this.parseCanonTimestamp(dateStr, timeStr);
    
    const files = await fs.readdir(sessionPath);
    const photos = [];
    const rawFiles = new Set();
    
    for (const file of files) {
      if (file.endsWith('.CR3')) {
        rawFiles.add(file.replace('.CR3', ''));
      }
    }
    
    for (const file of files) {
      if (!this.imageFormats.test(file)) continue;
      
      const baseName = file.replace(/\.(jpg|jpeg)/i, '');
      const filePath = path.join(sessionPath, file);
      const stat = await fs.stat(filePath);
      
      photos.push({
        filename: file,
        path: `card_download_1/${dirName}/${file}`,
        size: stat.size,
        hasRaw: rawFiles.has(baseName),
        type: 'canon'
      });
    }
    
    if (photos.length === 0) return null;
    
    photos.sort((a, b) => a.filename.localeCompare(b.filename));
    
    return {
      id: dirName,
      sessionNumber: parseInt(sessionNum),
      timestamp,
      dayOfWeek: this.getDayOfWeek(timestamp),
      source: 'Canon R5',
      type: 'burst',
      photoCount: photos.length,
      duration: this.calculateSessionDuration(photos, 'canon'),
      heroIndex: Math.floor(photos.length / 2),
      photos
    };
  }

  async indexIphoneSessions() {
    const sessions = [];
    const dirs = await fs.readdir(this.photoDirs.iphone);
    
    for (const dir of dirs) {
      if (!dir.startsWith('iphone_')) continue;
      
      const sessionPath = path.join(this.photoDirs.iphone, dir);
      const stat = await fs.stat(sessionPath);
      
      if (!stat.isDirectory()) continue;
      
      const session = await this.processIphoneSession(dir, sessionPath);
      if (session) sessions.push(session);
    }
    
    return sessions;
  }

  async processIphoneSession(dirName, sessionPath) {
    const match = dirName.match(/iphone_(\d+)_(\d{8})_(\d{6})/);
    if (!match) return null;
    
    const [, sessionNum, dateStr, timeStr] = match;
    const timestamp = this.parseCanonTimestamp(dateStr, timeStr);
    
    const files = await fs.readdir(sessionPath);
    const photos = [];
    
    for (const file of files) {
      if (!this.imageFormats.test(file)) continue;
      
      const filePath = path.join(sessionPath, file);
      const stat = await fs.stat(filePath);
      
      photos.push({
        filename: file,
        path: `iphone_sessions/${dirName}/${file}`,
        size: stat.size,
        hasRaw: false,
        type: 'iphone'
      });
    }
    
    if (photos.length === 0) return null;
    
    photos.sort((a, b) => a.filename.localeCompare(b.filename));
    
    return {
      id: dirName,
      sessionNumber: parseInt(sessionNum) + 1000, // Offset iPhone session numbers
      timestamp,
      dayOfWeek: this.getDayOfWeek(timestamp),
      source: 'iPhone',
      type: 'burst',
      photoCount: photos.length,
      duration: this.calculateSessionDuration(photos, 'iphone'),
      heroIndex: Math.floor(photos.length / 2),
      photos
    };
  }

  async indexIphoneDayOne() {
    const sessionPath = this.photoDirs.iphoneDayOne;
    const files = await fs.readdir(sessionPath);
    const photos = [];
    
    let earliestTime = null;
    
    for (const file of files) {
      if (!this.imageFormats.test(file)) continue;
      
      const filePath = path.join(sessionPath, file);
      const stat = await fs.stat(filePath);
      
      if (!earliestTime || stat.mtime < earliestTime) {
        earliestTime = stat.mtime;
      }
      
      photos.push({
        filename: file,
        path: `iphone_day_one_shots/${file}`,
        size: stat.size,
        hasRaw: false,
        type: 'iphone'
      });
    }
    
    if (photos.length === 0) return null;
    
    photos.sort((a, b) => a.filename.localeCompare(b.filename));
    
    return {
      id: 'iphone_day_one',
      sessionNumber: 999,
      timestamp: earliestTime ? earliestTime.toISOString() : '2025-08-25T12:00:00',
      dayOfWeek: 'sunday',
      source: 'iPhone',
      type: 'collection',
      photoCount: photos.length,
      duration: 0,
      heroIndex: Math.floor(photos.length / 2),
      photos
    };
  }

  parseCanonTimestamp(dateStr, timeStr) {
    const year = dateStr.substr(0, 4);
    const month = dateStr.substr(4, 2);
    const day = dateStr.substr(6, 2);
    const hour = timeStr.substr(0, 2);
    const minute = timeStr.substr(2, 2);
    const second = timeStr.substr(4, 2);
    
    return `${year}-${month}-${day}T${hour}:${minute}:${second}`;
  }

  getDayOfWeek(timestamp) {
    const days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
    const date = new Date(timestamp);
    return days[date.getDay()];
  }

  calculateSessionDuration(photos, type) {
    if (photos.length < 2) return 0;
    
    if (type === 'canon') {
      // Extract timestamps from Canon filenames
      const timestamps = photos.map(p => {
        const match = p.filename.match(/3Q7A(\d{4})/);
        return match ? parseInt(match[1]) : null;
      }).filter(Boolean);
      
      if (timestamps.length < 2) return 0;
      
      const first = Math.min(...timestamps);
      const last = Math.max(...timestamps);
      return (last - first) * 0.5; // Rough estimate
    }
    
    return 0;
  }

  calculateStats(sessions) {
    const stats = {
      totalSessions: sessions.length,
      totalPhotos: 0,
      byDay: {},
      bySource: {},
      largestSession: null,
      smallestSession: null
    };
    
    for (const session of sessions) {
      stats.totalPhotos += session.photoCount;
      
      // By day
      if (!stats.byDay[session.dayOfWeek]) {
        stats.byDay[session.dayOfWeek] = { sessions: 0, photos: 0 };
      }
      stats.byDay[session.dayOfWeek].sessions++;
      stats.byDay[session.dayOfWeek].photos += session.photoCount;
      
      // By source
      if (!stats.bySource[session.source]) {
        stats.bySource[session.source] = { sessions: 0, photos: 0 };
      }
      stats.bySource[session.source].sessions++;
      stats.bySource[session.source].photos += session.photoCount;
      
      // Largest/smallest
      if (!stats.largestSession || session.photoCount > stats.largestSession.photoCount) {
        stats.largestSession = { id: session.id, photoCount: session.photoCount };
      }
      if (!stats.smallestSession || session.photoCount < stats.smallestSession.photoCount) {
        stats.smallestSession = { id: session.id, photoCount: session.photoCount };
      }
    }
    
    return stats;
  }

  async directoryExists(dir) {
    try {
      const stat = await fs.stat(dir);
      return stat.isDirectory();
    } catch {
      return false;
    }
  }

  async getIndex() {
    try {
      const data = await fs.readFile(this.metadataFile, 'utf-8');
      return JSON.parse(data);
    } catch {
      // Index doesn't exist, create it
      return await this.indexAllPhotos();
    }
  }

  async refreshIndex() {
    return await this.indexAllPhotos();
  }
}

export default new PhotoIndexer();