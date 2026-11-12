/**
 * Minimo Brain Suite - Cross-Device WebSocket & State Controller
 */

// Configure Marked options
marked.setOptions({
  gfm: true,
  breaks: true,
});

const state = {
  mode: 'all',
  ws: null,
  wsConnected: false,
  conversationHistory: [],
  currentAgentBubble: null,
  currentCardContainer: null,
  currentRawResponse: '',
  pendingTasks: []
};

// DOM Elements
const chatDeck = document.getElementById('chatDeck');
const welcomeHero = document.getElementById('welcomeHero');
const queryInput = document.getElementById('queryInput');
const inputForm = document.getElementById('inputForm');
const statusDot = document.getElementById('statusDot');
const statusText = document.getElementById('statusText');
const tailscaleTag = document.getElementById('tailscaleTag');
const avatarFace = document.getElementById('avatarFace');
const liveStatusBar = document.getElementById('liveStatusBar');
const liveStatusLabel = document.getElementById('liveStatusLabel');
const tasksDrawer = document.getElementById('tasksDrawer');
const drawerOverlay = document.getElementById('drawerOverlay');
const tasksDrawerBtn = document.getElementById('tasksDrawerBtn');
const closeDrawerBtn = document.getElementById('closeDrawerBtn');
const drawerTasksList = document.getElementById('drawerTasksList');
const tasksCountBadge = document.getElementById('tasksCountBadge');
const clearChatBtn = document.getElementById('clearChatBtn');

// ── WebSocket Connection ──
function initWebSocket() {
  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  const wsUrl = `${protocol}//${window.location.host}/ws/chat`;

  statusText.textContent = "Connecting...";
  statusDot.classList.add('offline');

  try {
    state.ws = new WebSocket(wsUrl);

    state.ws.onopen = () => {
      state.wsConnected = true;
      statusDot.classList.remove('offline');
      statusText.textContent = "Online";
      setAvatarFace('✦');
      fetchServerStatus();
      fetchTasksList();
    };

    state.ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        handleServerPacket(data);
      } catch (err) {
        console.error("WS Parse error:", err, event.data);
      }
    };

    state.ws.onclose = () => {
      state.wsConnected = false;
      statusDot.classList.add('offline');
      statusText.textContent = "Reconnecting...";
      setAvatarFace('x_x');
      setTimeout(initWebSocket, 2500);
    };

    state.ws.onerror = (err) => {
      console.warn("WebSocket error:", err);
      state.ws.close();
    };
  } catch (e) {
    setTimeout(initWebSocket, 3000);
  }
}

// ── Character Reactions ──
function setAvatarFace(face) {
  if (avatarFace) {
    avatarFace.textContent = face;
  }
}

function handleReaction(reaction) {
  const map = {
    'thinking': '⋯',
    'curious': '?',
    'writing': '✎',
    'reading': '📖',
    'happyBounce': '✓',
    'sparkles': '✦',
    'neutral': '·'
  };
  setAvatarFace(map[reaction] || '✦');
}

// ── Server Status & Tasks Count ──
async function fetchServerStatus() {
  try {
    const res = await fetch('/api/status');
    const data = await res.json();
    if (data.tailscale_ip) {
      tailscaleTag.textContent = data.tailscale_ip;
      tailscaleTag.title = `Access directly from phone: http://${data.tailscale_ip}:8088`;
    }
  } catch (e) {
    console.warn("Status fetch failed", e);
  }
}

async function fetchTasksList() {
  try {
    const res = await fetch('/api/tasks');
    const data = await res.json();
    state.pendingTasks = data.tasks || [];
    tasksCountBadge.textContent = state.pendingTasks.length;
    renderDrawerTasks();
  } catch (e) {
    console.warn("Tasks fetch failed", e);
  }
}

// ── Packet Dispatcher ──
function handleServerPacket(pkt) {
  if (pkt.type === 'status') {
    liveStatusBar.style.display = 'flex';
    liveStatusLabel.textContent = pkt.text || 'Processing...';
    if (pkt.reaction) handleReaction(pkt.reaction);
  } 
  else if (pkt.type === 'token') {
    if (welcomeHero) welcomeHero.style.display = 'none';

    if (!state.currentAgentBubble) {
      createAgentMessage();
    }
    state.currentRawResponse += pkt.text;
    state.currentAgentBubble.innerHTML = marked.parse(state.currentRawResponse);
    scrollToBottom();
  } 
  else if (pkt.type === 'action_card') {
    if (welcomeHero) welcomeHero.style.display = 'none';

    if (!state.currentCardContainer) {
      if (!state.currentAgentBubble) createAgentMessage();
      state.currentCardContainer = document.createElement('div');
      state.currentCardContainer.className = 'action-cards-container';
      state.currentCardContainer.style.display = 'flex';
      state.currentCardContainer.style.flexDirection = 'row';
      state.currentCardContainer.style.flexWrap = 'nowrap';
      state.currentCardContainer.style.overflowX = 'auto';
      state.currentCardContainer.style.width = '100%';
      const msgDiv = state.currentAgentBubble.parentElement;
      msgDiv.insertBefore(state.currentCardContainer, state.currentAgentBubble);
    }
    renderActionCard(pkt, state.currentCardContainer);
    scrollToBottom();
  } 
  else if (pkt.type === 'done') {
    liveStatusBar.style.display = 'none';
    if (pkt.reaction) handleReaction(pkt.reaction);
    
    // Save to local conversation history
    if (state.currentRawResponse) {
      const last = state.conversationHistory[state.conversationHistory.length - 1];
      if (last && !last.a) {
        last.a = state.currentRawResponse;
      }
    }
    
    // Reset active stream pointers
    state.currentAgentBubble = null;
    state.currentCardContainer = null;
    state.currentRawResponse = '';
    
    // Refresh task count badge
    fetchTasksList();
  }
  else if (pkt.type === 'clear_session') {
    resetChatUI();
  }
}

// ── Chat Bubble Builders ──
function createUserMessage(text) {
  if (welcomeHero) welcomeHero.style.display = 'none';

  const msgDiv = document.createElement('div');
  msgDiv.className = 'message user';
  const bubble = document.createElement('div');
  bubble.className = 'user-bubble';
  bubble.textContent = text;
  msgDiv.appendChild(bubble);
  chatDeck.appendChild(msgDiv);
  scrollToBottom();
}

function createAgentMessage() {
  const msgDiv = document.createElement('div');
  msgDiv.className = 'message agent';
  const bubble = document.createElement('div');
  bubble.className = 'agent-bubble';
  msgDiv.appendChild(bubble);
  chatDeck.appendChild(msgDiv);
  state.currentAgentBubble = bubble;
  state.currentRawResponse = '';
}

function renderActionCard(card, container) {
  const cardEl = document.createElement('div');
  cardEl.className = 'action-card';
  cardEl.style.flex = '0 0 240px';
  cardEl.style.width = '240px';
  cardEl.style.minWidth = '200px';
  cardEl.style.flexShrink = '0';

  let iconName = 'sparkles';
  let defaultBadge = card.badge || 'Info';
  if (card.card_type === 'task') {
    iconName = 'check-square';
  } else if (card.card_type === 'movie' || card.card_type === 'media') {
    iconName = 'film';
  } else if (card.card_type === 'youtube') {
    iconName = 'play-circle';
  } else if (card.card_type === 'note') {
    iconName = 'file-text';
  } else if (card.card_type === 'book') {
    iconName = 'book-open';
  } else if (card.card_type === 'command') {
    iconName = 'terminal';
    defaultBadge = 'Copy';
  }

  cardEl.innerHTML = `
    <div class="card-left">
      <div class="card-icon-box">
        <i data-lucide="${iconName}"></i>
      </div>
      <div class="card-content">
        <div class="card-title">${escapeHtml(card.title)}</div>
        <div class="card-subtitle">${escapeHtml(card.subtitle || card.snippet || '')}</div>
      </div>
    </div>
    <div class="card-right">
      <span class="card-badge">${escapeHtml(defaultBadge)}</span>
    </div>
  `;

  cardEl.addEventListener('click', async () => {
    // 1. Task Toggle: Allowed from remote devices (syncs to Todoist)
    if (card.action_type === 'toggle_task') {
      cardEl.style.opacity = '0.5';
      await fetch('/api/tasks/toggle', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ task_id: card.action_payload })
      });
      const badge = cardEl.querySelector('.card-badge');
      badge.textContent = '✓ Done';
      badge.style.color = '#a6e3a1';
      fetchTasksList();
      return;
    }

    // 2. All other cards (commands, media, notes, books): COPY TO CLIPBOARD
    // Remote devices only receive information or copyable commands without launching desktop GUI apps.
    let textToCopy = card.action_payload || card.snippet || card.title;
    if (textToCopy && textToCopy.includes(':::')) {
      textToCopy = textToCopy.split(':::')[0];
    }

    if (navigator.clipboard && navigator.clipboard.writeText) {
      try {
        await navigator.clipboard.writeText(textToCopy);
        flashCardBadge(cardEl, '✓ Copied!');
        return;
      } catch (e) {}
    }

    // Fallback copy
    const textArea = document.createElement("textarea");
    textArea.value = textToCopy;
    document.body.appendChild(textArea);
    textArea.select();
    try {
      document.execCommand('copy');
      flashCardBadge(cardEl, '✓ Copied!');
    } catch (err) {
      flashCardBadge(cardEl, 'Info');
    }
    document.body.removeChild(textArea);
  });

  container.appendChild(cardEl);
  if (window.lucide) lucide.createIcons({ root: cardEl });
}

function flashCardBadge(cardEl, text) {
  const badge = cardEl.querySelector('.card-badge');
  if (!badge) return;
  const original = badge.textContent;
  badge.textContent = text;
  badge.style.color = '#a6e3a1';
  setTimeout(() => {
    badge.textContent = original;
    badge.style.color = '';
  }, 2000);
}

// ── Sending Queries ──
function submitQuery(queryText) {
  const q = (queryText || queryInput.value).trim();
  if (!q) return;

  if (q.toLowerCase() === 'clear' || q.toLowerCase() === 'cls' || q.toLowerCase() === 'reset') {
    resetChatUI();
    queryInput.value = '';
    return;
  }

  createUserMessage(q);
  state.conversationHistory.push({ q: q, a: '' });

  if (state.ws && state.ws.readyState === WebSocket.OPEN) {
    state.ws.send(JSON.stringify({
      query: q,
      mode: state.mode,
      history: state.conversationHistory.slice(-4)
    }));
  } else {
    // Fallback if WS dropped
    createAgentMessage();
    state.currentAgentBubble.innerHTML = "*(WebSocket connecting... please retry in a second)*";
  }

  queryInput.value = '';
  queryInput.style.height = 'auto';
}

function quickPrompt(prompt) {
  submitQuery(prompt);
}

function resetChatUI() {
  chatDeck.innerHTML = '';
  if (welcomeHero) {
    chatDeck.appendChild(welcomeHero);
    welcomeHero.style.display = 'block';
  }
  state.conversationHistory = [];
  state.currentAgentBubble = null;
  state.currentCardContainer = null;
  state.currentRawResponse = '';
  liveStatusBar.style.display = 'none';
  setAvatarFace('✦');
}

// ── Drawer & Tasks ──
function renderDrawerTasks() {
  drawerTasksList.innerHTML = '';
  if (!state.pendingTasks.length) {
    drawerTasksList.innerHTML = `
      <div style="text-align: center; padding: 30px; color: var(--text-sub);">
        ✨ No pending tasks found! You're completely caught up.
      </div>
    `;
    return;
  }

  state.pendingTasks.forEach(t => {
    const card = document.createElement('div');
    card.className = 'task-item-card';
    card.innerHTML = `
      <div style="display: flex; align-items: center; gap: 12px; min-width: 0;">
        <div class="task-check-circle" data-id="${t.id}">✓</div>
        <div style="min-width: 0;">
          <div class="task-title" style="font-size: 13.5px; font-weight: 500; color: #fff;">${escapeHtml(t.content)}</div>
          ${t.due ? `<div style="font-size: 11px; color: var(--accent-lavender); margin-top: 2px;">📅 ${escapeHtml(t.due)}</div>` : ''}
        </div>
      </div>
      <span class="card-badge">P${t.priority || 4}</span>
    `;

    const circle = card.querySelector('.task-check-circle');
    circle.addEventListener('click', async (e) => {
      e.stopPropagation();
      card.classList.add('completed');
      await fetch('/api/tasks/toggle', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ task_id: t.id })
      });
      setTimeout(fetchTasksList, 400);
    });

    drawerTasksList.appendChild(card);
  });
}

function openDrawer() {
  fetchTasksList();
  tasksDrawer.classList.add('active');
  drawerOverlay.classList.add('active');
}

function closeDrawer() {
  tasksDrawer.classList.remove('active');
  drawerOverlay.classList.remove('active');
}

// ── Event Listeners ──
tasksDrawerBtn.addEventListener('click', openDrawer);
closeDrawerBtn.addEventListener('click', closeDrawer);
drawerOverlay.addEventListener('click', closeDrawer);
clearChatBtn.addEventListener('click', resetChatUI);

// Mode Pills Switcher
document.querySelectorAll('.mode-pill').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.mode-pill').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    state.mode = btn.dataset.mode;
  });
});

// Auto-grow textarea & Enter handling
queryInput.addEventListener('input', () => {
  queryInput.style.height = 'auto';
  queryInput.style.height = Math.min(queryInput.scrollHeight, 120) + 'px';
});

queryInput.addEventListener('keydown', (e) => {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    submitQuery();
  }
});

inputForm.addEventListener('submit', (e) => {
  e.preventDefault();
  submitQuery();
});

// Utilities
function scrollToBottom() {
  chatDeck.scrollTop = chatDeck.scrollHeight;
}

function escapeHtml(str) {
  if (!str) return '';
  return str.replace(/[&<>'"]/g, 
    tag => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' }[tag] || tag)
  );
}

// Initialize Lucide icons and WebSocket
document.addEventListener('DOMContentLoaded', () => {
  if (window.lucide) lucide.createIcons();
  initWebSocket();
});
