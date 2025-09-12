import { createApp } from 'vue';
import { createPinia } from 'pinia';
import App from './App.vue';
import router from './router';

const app = createApp(App);

app.use(createPinia());
app.use(router);

app.mount('#app');

// Signal that app is ready (hides loading screen)
setTimeout(() => {
  window.dispatchEvent(new Event('app-ready'));
}, 500);