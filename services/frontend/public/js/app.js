// API Configuration
const API_BASE_URL = window.location.hostname === 'localhost' 
    ? 'http://localhost:8080/api' 
    : '/api';

// State
let allNamesCache = [];

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
    checkBackendHealth();
    // Check backend health every 30 seconds
    setInterval(checkBackendHealth, 30000);
});

/**
 * Get a random name from the backend
 */
async function getRandomName() {
    const nameDisplay = document.getElementById('nameDisplay');
    const getButton = document.querySelector('.btn-primary');
    
    try {
        // Show loading state
        nameDisplay.classList.add('loading');
        nameDisplay.textContent = 'Loading...';
        getButton.disabled = true;
        
        const response = await fetch(`${API_BASE_URL}/random-name`);
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const data = await response.json();
        
        // Display the random name
        nameDisplay.textContent = data.name;
        nameDisplay.classList.remove('loading');
        
        // Update stats
        await updateStats();
        
    } catch (error) {
        console.error('Error fetching random name:', error);
        nameDisplay.textContent = '❌ Error loading name';
        nameDisplay.classList.remove('loading');
        showMessage('Failed to get random name. Please try again.', 'error');
    } finally {
        getButton.disabled = false;
    }
}

/**
 * Add a new name to the list
 */
async function addName() {
    const input = document.getElementById('nameInput');
    const name = input.value.trim();
    
    if (!name) {
        showMessage('Please enter a name', 'error');
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE_URL}/random-name?name=${encodeURIComponent(name)}`, {
            method: 'POST'
        });
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const data = await response.json();
        
        if (data.success) {
            showMessage(data.message || 'Name added successfully!', 'success');
            input.value = '';
            await updateStats();
            
            // If names list is currently visible, refresh it
            const namesList = document.getElementById('namesList');
            if (!namesList.classList.contains('hidden')) {
                await loadAllNames();
            }
        } else {
            showMessage(data.message || 'Failed to add name', 'error');
        }
        
    } catch (error) {
        console.error('Error adding name:', error);
        showMessage('Failed to add name. Please try again.', 'error');
    }
}

/**
 * Load and display all names
 */
async function loadAllNames() {
    const namesList = document.getElementById('namesList');
    const namesUl = document.getElementById('namesUl');
    
    try {
        const response = await fetch(`${API_BASE_URL}/names`);
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const data = await response.json();
        allNamesCache = data.data || [];
        
        // Clear and populate the list
        namesUl.innerHTML = '';
        
        if (allNamesCache.length === 0) {
            namesUl.innerHTML = '<li>No names available</li>';
        } else {
            allNamesCache.forEach(name => {
                const li = document.createElement('li');
                li.innerHTML = `
                    <span>${name}</span>
                    <button class="delete-btn" onclick="deleteName('${name}')">Delete</button>
                `;
                namesUl.appendChild(li);
            });
        }
        
        // Show the list
        namesList.classList.remove('hidden');
        
    } catch (error) {
        console.error('Error loading names:', error);
        showMessage('Failed to load names list.', 'error');
    }
}

/**
 * Hide the names list
 */
function hideAllNames() {
    const namesList = document.getElementById('namesList');
    namesList.classList.add('hidden');
}

/**
 * Delete a specific name
 */
async function deleteName(name) {
    if (!confirm(`Are you sure you want to delete "${name}"?`)) {
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE_URL}/names/${encodeURIComponent(name)}`, {
            method: 'DELETE'
        });
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const data = await response.json();
        
        if (data.success) {
            showMessage(data.message || 'Name deleted successfully!', 'success');
            await updateStats();
            await loadAllNames(); // Refresh the list
        } else {
            showMessage(data.message || 'Failed to delete name', 'error');
        }
        
    } catch (error) {
        console.error('Error deleting name:', error);
        showMessage('Failed to delete name. Please try again.', 'error');
    }
}

/**
 * Update statistics display
 */
async function updateStats() {
    try {
        const response = await fetch(`${API_BASE_URL}/names`);
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const data = await response.json();
        const count = data.data ? data.data.length : 0;
        
        document.getElementById('nameCount').textContent = count;
        
    } catch (error) {
        console.error('Error updating stats:', error);
        document.getElementById('nameCount').textContent = '?';
    }
}

/**
 * Check backend health status
 */
async function checkBackendHealth() {
    const statusElement = document.getElementById('backendStatus');
    
    try {
        const response = await fetch(`${API_BASE_URL}/health`, {
            method: 'GET',
            cache: 'no-cache'
        });
        
        if (response.ok) {
            const data = await response.json();
            statusElement.textContent = '● Online';
            statusElement.className = 'online';
        } else {
            throw new Error('Backend unhealthy');
        }
        
    } catch (error) {
        console.error('Backend health check failed:', error);
        statusElement.textContent = '● Offline';
        statusElement.className = 'offline';
    }
}

/**
 * Show a message to the user
 */
function showMessage(message, type = 'success') {
    const messageDiv = document.getElementById('message');
    messageDiv.textContent = message;
    messageDiv.className = `message ${type}`;
    
    // Auto-hide after 5 seconds
    setTimeout(() => {
        messageDiv.textContent = '';
        messageDiv.className = 'message';
    }, 5000);
}

/**
 * Handle Enter key in name input
 */
document.addEventListener('DOMContentLoaded', () => {
    const nameInput = document.getElementById('nameInput');
    if (nameInput) {
        nameInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                addName();
            }
        });
    }
});
