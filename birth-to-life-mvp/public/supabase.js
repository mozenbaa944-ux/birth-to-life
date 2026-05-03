// Supabase client configuration
const SUPABASE_URL = 'https://tirxwwkzfdabihcimdmm.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRpcnh3d2t6ZmRhYmloY2ltZG1tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc4MDczNDAsImV4cCI6MjA5MzM4MzM0MH0.NUW8f2TQAXHlSSNf-VdnLPXnhiq5DZX22nYz1o_j3yw';

const { createClient } = supabase;
const db = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Toast notifications
const toastContainer = document.createElement('div');
toastContainer.className = 'toast-container';
document.body.appendChild(toastContainer);

function showToast(message, type = 'info', duration = 4000) {
  const icons = { success: '✓', error: '✕', info: 'ℹ', warning: '⚠' };
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.innerHTML = `<span style="font-size:16px;flex-shrink:0">${icons[type] || icons.info}</span><span>${message}</span>`;
  toastContainer.appendChild(toast);
  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateX(100%)';
    toast.style.transition = 'all 0.3s ease';
    setTimeout(() => toast.remove(), 300);
  }, duration);
}

// Auth helpers
async function getCurrentUser() {
  const { data: { user } } = await db.auth.getUser();
  return user;
}

async function getUserProfile(userId) {
  const { data } = await db.from('users').select('*').eq('id', userId).single();
  return data;
}

async function signOut() {
  await db.auth.signOut();
  window.location.href = 'index.html';
}

// Format date
function formatDate(dateStr) {
  if (!dateStr) return '—';
  return new Date(dateStr).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' });
}

// Calculate age
function calcAge(dob) {
  if (!dob) return '—';
  const today = new Date();
  const birth = new Date(dob);
  let years = today.getFullYear() - birth.getFullYear();
  let months = today.getMonth() - birth.getMonth();
  if (months < 0) { years--; months += 12; }
  if (years === 0) return `${months}m`;
  return months > 0 ? `${years}y ${months}m` : `${years}y`;
}

// File size formatter
function formatSize(bytes) {
  if (!bytes) return '';
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
}

// Get file icon
function getFileIcon(name) {
  const ext = (name || '').split('.').pop().toLowerCase();
  const map = { pdf: '📄', jpg: '🖼️', jpeg: '🖼️', png: '🖼️', gif: '🖼️', doc: '📝', docx: '📝', xls: '📊', xlsx: '📊' };
  return map[ext] || '📎';
}

// Modal helpers
function openModal(id) {
  document.getElementById(id).classList.add('open');
}
function closeModal(id) {
  document.getElementById(id).classList.remove('open');
}

// Close modals on overlay click
document.addEventListener('click', (e) => {
  if (e.target.classList.contains('modal-overlay')) {
    e.target.classList.remove('open');
  }
});

// Loading button helper
function setLoading(btn, loading) {
  if (loading) {
    btn._origHTML = btn.innerHTML;
    btn.innerHTML = '<span class="loading-spinner"></span> Loading...';
    btn.disabled = true;
  } else {
    btn.innerHTML = btn._origHTML || btn.innerHTML;
    btn.disabled = false;
  }
}
