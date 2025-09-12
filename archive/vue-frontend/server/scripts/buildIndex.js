#!/usr/bin/env node

import photoIndexer from '../utils/photoIndexer.js';
import fs from 'fs/promises';
import path from 'path';

async function buildIndex() {
  console.log('🔍 Building photo index...');
  console.log('================================');
  
  try {
    const startTime = Date.now();
    
    // Run the indexer
    const index = await photoIndexer.indexAllPhotos();
    
    const elapsed = ((Date.now() - startTime) / 1000).toFixed(2);
    
    console.log('\n✅ Index built successfully!');
    console.log('================================');
    console.log(`📊 Statistics:`);
    console.log(`  • Total sessions: ${index.stats.totalSessions}`);
    console.log(`  • Total photos: ${index.stats.totalPhotos}`);
    console.log(`  • Time taken: ${elapsed}s`);
    
    console.log('\n📅 Photos by day:');
    const days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
    for (const day of days) {
      if (index.stats.byDay[day]) {
        const dayStats = index.stats.byDay[day];
        console.log(`  • ${day.charAt(0).toUpperCase() + day.slice(1)}: ${dayStats.sessions} sessions, ${dayStats.photos} photos`);
      }
    }
    
    console.log('\n📷 Photos by source:');
    for (const [source, stats] of Object.entries(index.stats.bySource)) {
      console.log(`  • ${source}: ${stats.sessions} sessions, ${stats.photos} photos`);
    }
    
    console.log('\n📝 Index saved to: photo_index.json');
    
  } catch (error) {
    console.error('❌ Error building index:', error);
    process.exit(1);
  }
}

// Run if called directly
if (process.argv[1] === new URL(import.meta.url).pathname) {
  buildIndex();
}

export default buildIndex;