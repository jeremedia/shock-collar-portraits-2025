import { defineStore } from 'pinia';
import { ref, computed } from 'vue';

export const useEmailStore = defineStore('emails', () => {
  const emails = ref({});
  const emailsList = ref([]);
  
  // Load emails from localStorage
  function loadEmails() {
    try {
      const stored = localStorage.getItem('shock_collar_emails');
      if (stored) {
        emails.value = JSON.parse(stored);
        updateEmailsList();
      }
    } catch (err) {
      console.error('Failed to load emails:', err);
      emails.value = {};
    }
  }
  
  // Save email for a session
  function saveEmail(sessionId, data) {
    const timestamp = new Date().toISOString();
    
    emails.value[sessionId] = {
      name: data.name || '',
      email: data.email,
      notes: data.notes || '',
      timestamp,
      sessionNumber: data.sessionNumber || sessionId.match(/\d+/)?.[0]
    };
    
    localStorage.setItem('shock_collar_emails', JSON.stringify(emails.value));
    updateEmailsList();
  }
  
  // Remove email for a session
  function removeEmail(sessionId) {
    delete emails.value[sessionId];
    localStorage.setItem('shock_collar_emails', JSON.stringify(emails.value));
    updateEmailsList();
  }
  
  // Get email for a session
  function getEmail(sessionId) {
    return emails.value[sessionId] || null;
  }
  
  // Update flat list for easier access
  function updateEmailsList() {
    emailsList.value = Object.entries(emails.value).map(([sessionId, data]) => ({
      sessionId,
      ...data
    })).sort((a, b) => {
      const numA = parseInt(a.sessionNumber) || 0;
      const numB = parseInt(b.sessionNumber) || 0;
      return numA - numB;
    });
  }
  
  // Export emails as CSV
  function exportAsCSV() {
    const csv = [
      'Session,Name,Email,Notes,Timestamp',
      ...emailsList.value.map(e => 
        `${e.sessionNumber},"${e.name}","${e.email}","${e.notes}","${e.timestamp}"`
      )
    ].join('\n');
    
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `shock_collar_emails_${new Date().toISOString().split('T')[0]}.csv`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }
  
  // Export emails as JSON
  function exportAsJSON() {
    const data = {
      emails: emails.value,
      emailsList: emailsList.value,
      exportedAt: new Date().toISOString(),
      totalEmails: emailsList.value.length
    };
    
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `shock_collar_emails_${new Date().toISOString().split('T')[0]}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }
  
  // Export for mail merge (name and email only)
  function exportForMailMerge() {
    const csv = [
      'Name,Email',
      ...emailsList.value.map(e => `"${e.name}","${e.email}"`)
    ].join('\n');
    
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `shock_collar_mailmerge_${new Date().toISOString().split('T')[0]}.csv`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }
  
  // Import emails from JSON
  function importEmails(data) {
    try {
      if (typeof data === 'string') {
        data = JSON.parse(data);
      }
      
      if (data.emails) {
        emails.value = { ...emails.value, ...data.emails };
        localStorage.setItem('shock_collar_emails', JSON.stringify(emails.value));
        updateEmailsList();
        return true;
      }
    } catch (err) {
      console.error('Failed to import emails:', err);
    }
    return false;
  }
  
  // Stats computed
  const totalEmails = computed(() => emailsList.value.length);
  const emailsByDay = computed(() => {
    const byDay = {};
    emailsList.value.forEach(e => {
      const day = new Date(e.timestamp).toLocaleDateString('en-US', { weekday: 'long' }).toLowerCase();
      if (!byDay[day]) byDay[day] = [];
      byDay[day].push(e);
    });
    return byDay;
  });
  
  return {
    emails,
    emailsList,
    totalEmails,
    emailsByDay,
    loadEmails,
    saveEmail,
    removeEmail,
    getEmail,
    exportAsCSV,
    exportAsJSON,
    exportForMailMerge,
    importEmails
  };
});