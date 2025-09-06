#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const markdownPath = '/Users/jeremy/Desktop/OK-SHOCK-25/Shock Collar Portraits 2025 sessions 1 through 3 emails/Shock Collar Portraits 2025.md';

// Read and parse the markdown file
const content = fs.readFileSync(markdownPath, 'utf-8');
const lines = content.split('\n');

const emails = {};
let currentSession = 1;
let dayCounter = { monday: 0, tuesday: 0, wednesday: 0 };
let currentDay = 'monday';

lines.forEach(line => {
  // Detect day headers
  if (line.toLowerCase().includes('monday')) {
    currentDay = 'monday';
    return;
  }
  if (line.toLowerCase().includes('tuesday')) {
    currentDay = 'tuesday';
    currentSession = 55; // Tuesday starts after Monday's 54
    return;
  }
  if (line.toLowerCase().includes('session three')) {
    currentDay = 'wednesday';
    currentSession = 120; // Approximate start for session three
    return;
  }
  
  // Parse email lines
  const emailRegex = /[\w._%+-]+@[\w.-]+\.[A-Z|a-z]{2,}/gi;
  const emailMatch = line.match(emailRegex);
  
  if (emailMatch) {
    const email = emailMatch[0];
    
    // Extract name from various formats
    let name = '';
    
    // Format 1: "1. Name - email@domain.com"
    // Format 2: "Name [email@domain.com]"
    // Format 3: "- [ ] email@domain.com"
    
    if (line.includes('[') && line.includes(']')) {
      // Email is in brackets, name is before
      name = line.split('[')[0]
        .replace(/^\d+\.\s*/, '') // Remove number
        .replace(/^-\s*\[\s*\]\s*/, '') // Remove checkbox
        .trim();
    } else if (line.includes('-')) {
      // Name before dash
      name = line.split('-')[0]
        .replace(/^\d+\.\s*/, '') // Remove number
        .trim();
    } else {
      // Just try to get text before email
      name = line.split(email)[0]
        .replace(/^\d+\.\s*/, '') // Remove number
        .replace(/^-\s*\[\s*\]\s*/, '') // Remove checkbox
        .replace(/[^\w\s']/g, '') // Remove special chars
        .trim();
    }
    
    // Generate session ID
    const sessionId = `burst_${String(currentSession).padStart(3, '0')}_imported`;
    
    emails[sessionId] = {
      name: name || '',
      email: email,
      sessionNumber: currentSession,
      notes: `Imported from ${currentDay}`,
      timestamp: new Date().toISOString()
    };
    
    console.log(`${currentSession}. ${name || 'No name'} - ${email} (${currentDay})`);
    currentSession++;
  }
});

// Create the import data structure
const importData = {
  emails,
  totalEmails: Object.keys(emails).length,
  importedAt: new Date().toISOString()
};

// Save to file for manual import via UI
const outputPath = path.join(__dirname, '../../email_import.json');
fs.writeFileSync(outputPath, JSON.stringify(importData, null, 2));

console.log(`\nProcessed ${Object.keys(emails).length} emails`);
console.log(`Saved to: ${outputPath}`);
console.log('\nYou can now import this file through the Email Collector UI');