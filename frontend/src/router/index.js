import { createRouter, createWebHistory } from 'vue-router';
import GalleryView from '../views/GalleryView.vue';
import SessionView from '../views/SessionView.vue';
import SlideshowView from '../views/SlideshowView.vue';
import EmailCollector from '../views/EmailCollector.vue';

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      name: 'gallery',
      component: GalleryView
    },
    {
      path: '/slideshow',
      name: 'slideshow',
      component: SlideshowView
    },
    {
      path: '/emails',
      name: 'emails',
      component: EmailCollector
    },
    {
      path: '/session/:id',
      name: 'session',
      component: SessionView,
      props: true
    }
  ],
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) {
      return savedPosition;
    } else if (to.hash) {
      return {
        el: to.hash,
        behavior: 'smooth'
      };
    } else {
      return { top: 0 };
    }
  }
});

export default router;