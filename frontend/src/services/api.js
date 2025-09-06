import axios from 'axios';

// Rails API configuration
const API_BASE = window.location.hostname === 'localhost' 
  ? 'http://localhost:4000' 
  : `http://${window.location.hostname}:4000`;

console.log('Rails API Base URL:', API_BASE);

const api = axios.create({
  baseURL: `${API_BASE}/api`,
  headers: {
    'Content-Type': 'application/json'
  },
  withCredentials: true
});

export default {
  async getSessions() {
    const { data } = await api.get('/sessions');
    return data.sessions;
  },

  async getSessionsByDay() {
    const { data } = await api.get('/sessions');
    // Group sessions by day for compatibility
    const byDay = {};
    data.sessions.forEach(session => {
      if (!byDay[session.dayOfWeek]) {
        byDay[session.dayOfWeek] = [];
      }
      byDay[session.dayOfWeek].push(session);
    });
    return byDay;
  },

  async getSession(sessionId) {
    const { data } = await api.get(`/sessions/${sessionId}`);
    return data;
  },

  async getAdjacentSessions(sessionId) {
    // Get all sessions and find adjacent ones
    const { data } = await api.get('/sessions');
    const sessions = data.sessions;
    const currentIndex = sessions.findIndex(s => s.id === sessionId);
    
    return {
      previous: currentIndex > 0 ? sessions[currentIndex - 1] : null,
      next: currentIndex < sessions.length - 1 ? sessions[currentIndex + 1] : null
    };
  },

  async getSelections() {
    // For now, still use localStorage for selections until migrated
    const selections = localStorage.getItem('heroSelections');
    return selections ? JSON.parse(selections) : {};
  },

  async getSelection(sessionId) {
    const selections = await this.getSelections();
    return selections[sessionId];
  },

  async saveSelection(sessionId, photoIndex, filename) {
    // Save to Rails
    await api.put(`/sessions/${sessionId}/update_hero`, {
      hero_index: photoIndex
    });
    
    // Also save to localStorage for now
    const selections = await this.getSelections();
    selections[sessionId] = photoIndex;
    localStorage.setItem('heroSelections', JSON.stringify(selections));
    
    return { success: true };
  },

  async removeSelection(sessionId) {
    const selections = await this.getSelections();
    delete selections[sessionId];
    localStorage.setItem('heroSelections', JSON.stringify(selections));
    return { success: true };
  },

  async exportSelections(format = 'json') {
    const selections = await this.getSelections();
    return { selections, format };
  },

  async preloadImages(sessionId, photos, size = 'medium') {
    // Not needed with Rails serving
    return { success: true };
  },

  getImageUrl(sessionId, filename, size = 'original', format = 'original') {
    // For now, use direct file serving through Rails
    // Find the photo path from the session
    const path = `card_download_1/${sessionId}/${filename}`;
    return `${API_BASE}/photos/${path}`;
  },

  // New methods for sittings
  async createSitting(sessionNumber, data) {
    const { data: response } = await api.post('/sittings', {
      session_number: sessionNumber,
      sitting: data
    });
    return response;
  },

  async updateSitting(sittingId, data) {
    const { data: response } = await api.put(`/sittings/${sittingId}`, {
      sitting: data
    });
    return response;
  }
};