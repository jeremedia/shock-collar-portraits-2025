import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import api from '../services/api';

export const useGalleryStore = defineStore('gallery', () => {
  const sessions = ref([]);
  const currentSession = ref(null);
  const selections = ref({});
  const collapsedDays = ref({});
  const loading = ref(false);
  const error = ref(null);

  const sessionsByDay = computed(() => {
    const byDay = {};
    sessions.value.forEach(session => {
      const day = session.dayOfWeek || session.dayName; // Support both field names
      if (!byDay[day]) {
        byDay[day] = [];
      }
      byDay[day].push(session);
    });
    return byDay;
  });

  const selectedCount = computed(() => {
    return Object.keys(selections.value).length;
  });

  async function loadSessions() {
    loading.value = true;
    error.value = null;
    try {
      const data = await api.getSessions();
      sessions.value = data;
      
      const savedCollapsed = localStorage.getItem('gallery_collapsed_days');
      if (savedCollapsed) {
        collapsedDays.value = JSON.parse(savedCollapsed);
      }
    } catch (err) {
      error.value = err.message;
    } finally {
      loading.value = false;
    }
  }

  async function loadSession(sessionId) {
    loading.value = true;
    error.value = null;
    try {
      const data = await api.getSession(sessionId);
      currentSession.value = data;
      return data;
    } catch (err) {
      error.value = err.message;
      return null;
    } finally {
      loading.value = false;
    }
  }

  async function loadSelections() {
    try {
      // First try to load from localStorage
      const localSelections = localStorage.getItem('shock_collar_selections');
      if (localSelections) {
        selections.value = JSON.parse(localSelections);
      }
      
      // Also try to sync with server (but don't overwrite local)
      try {
        const serverData = await api.getSelections();
        // Merge server data with local data, preferring local
        selections.value = { ...serverData, ...selections.value };
        // Save merged data back to localStorage
        localStorage.setItem('shock_collar_selections', JSON.stringify(selections.value));
      } catch (serverErr) {
        // Server might not be available, that's OK - we have local data
        console.log('Using local selections only');
      }
    } catch (err) {
      console.error('Failed to load selections:', err);
      selections.value = {};
    }
  }

  async function saveSelection(sessionId, photoIndex, filename) {
    // Always save to localStorage immediately
    selections.value[sessionId] = { 
      photoIndex, 
      filename,
      timestamp: new Date().toISOString()
    };
    localStorage.setItem('shock_collar_selections', JSON.stringify(selections.value));
    
    // Also try to save to server (non-blocking)
    try {
      await api.saveSelection(sessionId, photoIndex, filename);
    } catch (err) {
      console.warn('Failed to save selection to server (saved locally):', err);
    }
  }

  async function removeSelection(sessionId) {
    // Remove from localStorage immediately
    delete selections.value[sessionId];
    localStorage.setItem('shock_collar_selections', JSON.stringify(selections.value));
    
    // Also try to remove from server (non-blocking)
    try {
      await api.removeSelection(sessionId);
    } catch (err) {
      console.warn('Failed to remove selection from server (removed locally):', err);
    }
  }

  function toggleDay(dayName) {
    collapsedDays.value[dayName] = !collapsedDays.value[dayName];
    localStorage.setItem('gallery_collapsed_days', JSON.stringify(collapsedDays.value));
  }

  function isDayCollapsed(dayName) {
    return !!collapsedDays.value[dayName];
  }

  async function preloadImages(sessionId, filenames, size = 'medium') {
    try {
      await api.preloadImages(sessionId, filenames, size);
    } catch (err) {
      console.error('Failed to preload images:', err);
    }
  }

  function exportSelections() {
    const data = {
      selections: selections.value,
      exportedAt: new Date().toISOString(),
      totalSelections: Object.keys(selections.value).length
    };
    
    // Create a downloadable JSON file
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `shock_collar_selections_${new Date().toISOString().split('T')[0]}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    
    return data;
  }

  function importSelections(data) {
    try {
      if (typeof data === 'string') {
        data = JSON.parse(data);
      }
      
      if (data.selections) {
        selections.value = { ...selections.value, ...data.selections };
        localStorage.setItem('shock_collar_selections', JSON.stringify(selections.value));
        return true;
      }
    } catch (err) {
      console.error('Failed to import selections:', err);
    }
    return false;
  }

  return {
    sessions,
    currentSession,
    selections,
    collapsedDays,
    loading,
    error,
    sessionsByDay,
    selectedCount,
    loadSessions,
    loadSession,
    loadSelections,
    saveSelection,
    removeSelection,
    toggleDay,
    isDayCollapsed,
    preloadImages,
    exportSelections,
    importSelections
  };
});