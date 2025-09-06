<template>
  <router-view />
</template>

<script setup>
</script>

<style>
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
  background: #1a1a1a;
  background-image: 
    repeating-linear-gradient(
      45deg,
      #1a1a1a,
      #1a1a1a 10px,
      #222 10px,
      #222 20px
    );
}

#app {
  min-height: 100vh;
  /* Account for iOS safe areas */
  padding-left: env(safe-area-inset-left, 0);
  padding-right: env(safe-area-inset-right, 0);
}
</style>