<template>
  <div class="gallery-container">
    <header class="gallery-header">
      <h1>OKNOTOK</h1>
      <h2>Shock Collar Portraits</h2>
      <div class="stats">
        <span>{{ totalSessions }} sessions</span>
        <span class="separator">•</span>
        <span>{{ selectedCount }} selected</span>
        <span class="separator">•</span>
        <router-link to="/emails" class="action-btn" title="Collect emails">
          📧 Emails
        </router-link>
        <router-link to="/slideshow" class="action-btn" title="View slideshow of hero shots">
          ▶ Slideshow
        </router-link>
        <button @click="exportSelections" class="action-btn" title="Export selections (Ctrl+S)">
          💾 Export
        </button>
      </div>
    </header>

    <nav class="day-nav">
      <a 
        v-for="day in dayOrder" 
        :key="day"
        :href="`#${day}`"
        class="day-link"
        :class="{ active: sessionsByDay[day] }"
      >
        {{ capitalizeDay(day) }}
      </a>
    </nav>

    <div class="sessions-container">
      <div 
        v-for="day in availableDays" 
        :key="day"
        :id="day"
        class="day-section"
      >
        <h3 
          class="day-header"
          @click="toggleDay(day)"
        >
          <span class="day-toggle">{{ isDayCollapsed(day) ? '▶' : '▼' }}</span>
          {{ capitalizeDay(day) }}
          <span class="day-count">{{ sessionsByDay[day].length }} sessions</span>
        </h3>

        <div 
          v-show="!isDayCollapsed(day)"
          class="day-sessions"
        >
          <SessionCard
            v-for="session in sessionsByDay[day]"
            :id="`session-${session.id}`"
            :key="session.id"
            :session="session"
            :selected="!!selections[session.id]"
            @click="goToSession(session.id)"
          />
        </div>
      </div>
    </div>

    <div v-if="loading" class="loading">Loading sessions...</div>
    <div v-if="error" class="error">{{ error }}</div>
  </div>
</template>

<script setup>
import { computed, onMounted, onUnmounted } from 'vue';
import { useRouter } from 'vue-router';
import { useGalleryStore } from '../stores/gallery';
import SessionCard from '../components/SessionCard.vue';

const router = useRouter();
const store = useGalleryStore();

const dayOrder = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];

const totalSessions = computed(() => store.sessions.length);
const selectedCount = computed(() => store.selectedCount);
const sessionsByDay = computed(() => store.sessionsByDay);
const selections = computed(() => store.selections);
const loading = computed(() => store.loading);
const error = computed(() => store.error);

const availableDays = computed(() => {
  return dayOrder.filter(day => sessionsByDay.value[day]);
});

const isDayCollapsed = (day) => store.isDayCollapsed(day);
const toggleDay = (day) => store.toggleDay(day);

const capitalizeDay = (day) => {
  return day.charAt(0).toUpperCase() + day.slice(1);
};

const goToSession = (sessionId) => {
  router.push({ name: 'session', params: { id: sessionId } });
};

const exportSelections = () => {
  const data = store.exportSelections();
  console.log(`Exported ${data.totalSelections} selections to file`);
};

const handleKeyPress = (e) => {
  // Ctrl+S or Cmd+S to export selections
  if ((e.ctrlKey || e.metaKey) && e.key === 's') {
    e.preventDefault();
    exportSelections();
  }
};

onMounted(async () => {
  await store.loadSessions();
  await store.loadSelections();
  
  // Add keyboard event listener
  document.addEventListener('keydown', handleKeyPress);
  
  // If there's a hash in the URL, ensure the day is expanded
  if (window.location.hash) {
    const hash = window.location.hash.substring(1);
    if (hash.startsWith('session-')) {
      // Find which day this session belongs to
      const sessionId = hash.replace('session-', '');
      for (const [day, sessions] of Object.entries(sessionsByDay.value)) {
        if (sessions.some(s => s.id === sessionId)) {
          // Ensure this day is expanded
          if (store.isDayCollapsed(day)) {
            store.toggleDay(day);
          }
          break;
        }
      }
    }
  }
});

onUnmounted(() => {
  document.removeEventListener('keydown', handleKeyPress);
});
</script>

<style scoped>
.gallery-container {
  max-width: 1400px;
  margin: 0 auto;
  padding: 20px;
  padding-top: calc(20px + env(safe-area-inset-top, 0px));
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
}

.gallery-header {
  text-align: center;
  margin-bottom: 40px;
  padding: 40px 20px;
  background: linear-gradient(135deg, #000 0%, #c9302c 25%, #d4af37 50%, #c9302c 75%, #000 100%);
  color: #d4af37;
  border-radius: 10px;
  border: 3px solid #d4af37;
  box-shadow: 0 4px 20px rgba(212, 175, 55, 0.3);
  position: relative;
  overflow: hidden;
}

.gallery-header::before {
  content: '';
  position: absolute;
  top: 0;
  left: -100%;
  width: 100%;
  height: 100%;
  background: linear-gradient(90deg, transparent, rgba(212, 175, 55, 0.2), transparent);
  animation: shimmer 3s infinite;
}

@keyframes shimmer {
  100% {
    left: 100%;
  }
}

.gallery-header h1 {
  font-size: 3.5em;
  margin: 0;
  font-weight: 900;
  letter-spacing: 4px;
  text-shadow: 
    3px 3px 0px #c9302c,
    6px 6px 0px #000,
    6px 6px 20px rgba(212, 175, 55, 0.5);
  animation: glow 2s ease-in-out infinite alternate;
}

@keyframes glow {
  from {
    text-shadow: 
      3px 3px 0px #c9302c,
      6px 6px 0px #000,
      6px 6px 20px rgba(212, 175, 55, 0.5);
  }
  to {
    text-shadow: 
      3px 3px 0px #c9302c,
      6px 6px 0px #000,
      6px 6px 30px rgba(212, 175, 55, 0.8);
  }
}

.gallery-header h2 {
  font-size: 1.5em;
  margin: 10px 0 20px 0;
  font-weight: normal;
  color: #fff;
  text-transform: uppercase;
  letter-spacing: 2px;
}

.stats {
  font-size: 1.1em;
  color: #fff;
  font-weight: 600;
}

.separator {
  margin: 0 10px;
  color: #d4af37;
}

.action-btn {
  background: #c9302c;
  border: 2px solid #d4af37;
  color: #fff;
  padding: 6px 14px;
  border-radius: 5px;
  cursor: pointer;
  font-size: 0.95em;
  font-weight: bold;
  transition: all 0.2s;
  margin-left: 5px;
  text-transform: uppercase;
  text-decoration: none;
  display: inline-block;
}

.action-btn:hover {
  background: #d4af37;
  color: #000;
  transform: translateY(-2px);
  box-shadow: 0 4px 10px rgba(212, 175, 55, 0.4);
}

.day-nav {
  display: flex;
  justify-content: center;
  gap: 20px;
  margin-bottom: 30px;
  padding: 20px;
  background: #000;
  border-radius: 8px;
  flex-wrap: wrap;
  border: 2px solid #c9302c;
}

.day-link {
  padding: 10px 20px;
  text-decoration: none;
  color: #d4af37;
  border-radius: 5px;
  transition: all 0.2s;
  text-transform: uppercase;
  font-weight: bold;
  border: 2px solid transparent;
  background: rgba(201, 48, 44, 0.2);
}

.day-link:hover {
  background: #c9302c;
  border-color: #d4af37;
  transform: scale(1.05);
}

.day-link.active {
  background: #d4af37;
  color: #000;
  border-color: #d4af37;
  box-shadow: 0 0 10px rgba(212, 175, 55, 0.5);
}

.day-section {
  margin-bottom: 40px;
}

.day-header {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 15px 20px;
  background: linear-gradient(90deg, #000 0%, #1a0a0a 50%, #000 100%);
  border: 2px solid #c9302c;
  border-radius: 8px;
  cursor: pointer;
  user-select: none;
  transition: all 0.2s;
  color: #d4af37;
  font-weight: bold;
  text-transform: uppercase;
}

.day-header:hover {
  background: linear-gradient(90deg, #1a0000 0%, #2a0a0a 50%, #1a0000 100%);
  border-color: #d4af37;
  box-shadow: 0 2px 10px rgba(212, 175, 55, 0.2);
}

.day-toggle {
  font-size: 0.8em;
  width: 20px;
  color: #fff;
}

.day-count {
  margin-left: auto;
  font-size: 0.9em;
  color: #fff;
  font-weight: normal;
  background: rgba(212, 175, 55, 0.2);
  padding: 2px 10px;
  border-radius: 15px;
}

.day-sessions {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
  gap: 20px;
  padding: 20px 0;
}

.loading, .error {
  text-align: center;
  padding: 40px;
  font-size: 1.2em;
}

.error {
  color: #c9302c;
}
</style>