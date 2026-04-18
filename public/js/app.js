// Immediate theme application to prevent flickering
(function() {
  const savedTheme = localStorage.getItem('theme') || 'light';
  document.documentElement.setAttribute('data-theme', savedTheme);
  
  // Also update highlight.js style immediately if possible (will be checked again on DOMContentLoaded)
  const hljsLink = document.getElementById('hljs-style');
  if (hljsLink) {
    hljsLink.href = savedTheme === 'dark' 
      ? "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css"
      : "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css";
  }
})();

document.addEventListener('DOMContentLoaded', (event) => {
  const savedTheme = localStorage.getItem('theme') || 'light';
  updateThemeUI(savedTheme);

  if (typeof hljs !== 'undefined') {
    hljs.configure({ ignoreUnescapedHTML: true });
    document.querySelectorAll('code').forEach((el) => {
      hljs.highlightElement(el);
    });
  }
});

function updateThemeUI(theme) {
  document.documentElement.setAttribute('data-theme', theme);
  
  const hljsLink = document.getElementById('hljs-style');
  if (hljsLink) {
    hljsLink.href = theme === 'dark'
      ? "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css"
      : "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css";
  }

  const btn = document.getElementById('theme-btn');
  if (btn) {
    btn.textContent = theme === 'dark' ? '☀️ Light Mode' : '🌙 Dark Mode';
  }
}

// Make functions global explicitly
window.setTheme = function(theme) {
  localStorage.setItem('theme', theme);
  updateThemeUI(theme);
}

window.toggleTheme = function() {
  const currentTheme = document.documentElement.getAttribute('data-theme');
  const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
  window.setTheme(newTheme);
}

window.toggleForm = function(id) {
  var lineId = id.replace('new-', '');
  var area = document.getElementById('area-' + lineId);
  var f = document.getElementById('form-' + id);
  var addBtnContainer = document.getElementById('add-btn-container-' + lineId);

  if (f.style.display === 'block') {
    f.style.display = 'none';
    if (addBtnContainer) addBtnContainer.style.display = 'block';

    var list = document.getElementById('comments-list-' + lineId);
    if (list && list.children.length === 0) {
      area.style.display = 'none';
    }
  } else {
    area.style.display = 'block';
    f.style.display = 'block';
    if (addBtnContainer) addBtnContainer.style.display = 'none';
  }
}

window.showEditForm = function(lineId, idx) {
  document.getElementById('comment-' + lineId + '-' + idx).style.display = 'none';
  document.getElementById('edit-form-' + lineId + '-' + idx).style.display = 'block';
}

window.hideEditForm = function(lineId, idx) {
  document.getElementById('comment-' + lineId + '-' + idx).style.display = 'block';
  document.getElementById('edit-form-' + lineId + '-' + idx).style.display = 'none';
}

window.confirmDelete = function(lineId, idx) {
  if (confirm('Are you sure you want to delete this comment?')) {
    document.getElementById('delete-line-id').value = lineId;
    document.getElementById('delete-index').value = idx;
    document.getElementById('delete-form').submit();
  }
}
