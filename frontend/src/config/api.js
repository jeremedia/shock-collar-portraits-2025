// API configuration
const API_BASE = import.meta.env.PROD 
  ? '/api'  // In production, use relative path
  : 'http://localhost:4000/api';  // In development, use Rails server

export const API_ENDPOINTS = {
  sessions: `${API_BASE}/sessions`,
  session: (id) => `${API_BASE}/sessions/${id}`,
  updateHero: (id) => `${API_BASE}/sessions/${id}/update_hero`,
  sittings: `${API_BASE}/sittings`,
  sitting: (id) => `${API_BASE}/sittings/${id}`,
  photos: (path) => `http://localhost:4000/photos/${path}`
};

export default API_BASE;