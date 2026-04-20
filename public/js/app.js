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
    const form = document.getElementById('delete-form');
    const formData = new FormData(form);
    formData.set('line_id', lineId);
    formData.set('index', idx);
    formData.append('ajax', '1');

    fetch('/comment/delete', {
      method: 'POST',
      body: formData
    })
    .then(res => res.json())
    .then(data => {
      if (data.status === 'success') {
        const commentBox = document.getElementById(`comment-${lineId}-${idx}`);
        const editForm = document.getElementById(`edit-form-${lineId}-${idx}`);
        commentBox.remove();
        editForm.remove();

        const list = document.getElementById(`comments-list-${lineId}`);
        if (list.children.length === 0) {
          document.getElementById(`area-${lineId}`).style.display = 'none';
        }
      }
    });
  }
}

window.submitCommentForm = function(event, form) {
  event.preventDefault();
  const formData = new FormData(form);
  formData.append('ajax', '1');

  fetch(form.action, {
    method: 'POST',
    body: formData
  })
  .then(res => res.json())
  .then(data => {
    if (data.status === 'success') {
      const lineId = data.line_id;
      if (form.action.includes('update')) {
        // Update existing comment
        const idx = data.index;
        document.getElementById(`comment-${lineId}-${idx}`).querySelector('.comment-text').innerHTML = data.content_html;
        document.getElementById(`edit-form-${lineId}-${idx}`).querySelector('textarea').value = data.raw_content;
        window.hideEditForm(lineId, idx);
      } else {
        // Add new comment
        const list = document.getElementById(`comments-list-${lineId}`);
        const idx = data.index;
        const commentHtml = `
          <div class="comment-box" id="comment-${lineId}-${idx}">
            <div class="comment-text">${data.content_html}</div>
            <div class="comment-actions">
              <a onclick="showEditForm('${lineId}', ${idx})">Edit</a>
              <a onclick="confirmDelete('${lineId}', ${idx})">Delete</a>
            </div>
          </div>
          <div id="edit-form-${lineId}-${idx}" class="comment-form" style="display:none;">
            <form action="/comment/update" method="post" onsubmit="submitCommentForm(event, this)">
              <input type="hidden" name="filename" value="${formData.get('filename')}">
              <input type="hidden" name="path" value="${formData.get('path')}">
              <input type="hidden" name="mode" value="${formData.get('mode')}">
              <input type="hidden" name="line_id" value="${lineId}">
              <input type="hidden" name="index" value="${idx}">
              <textarea name="content" rows="6">${data.raw_content}</textarea>
              <div class="form-actions">
                <button type="button" class="btn btn-cancel" onclick="hideEditForm('${lineId}', ${idx})">Cancel</button>
                <button type="submit" class="btn btn-primary">Update</button>
              </div>
            </form>
          </div>
        `;
        list.insertAdjacentHTML('beforeend', commentHtml);
        form.reset();
        window.toggleForm(`new-${lineId}`);
        
        // Ensure the "Add a comment" button is visible if it was hidden
        const addBtnContainer = document.getElementById(`add-btn-container-${lineId}`);
        if (!addBtnContainer && list.children.length === 1) {
           // If it's the first comment, we might need to create the container or just show the area
           // Actually, in the template, area is hidden if no comments.
           // ToggleForm already handles showing the area.
        }
      }
    }
  });
};

window.copyToClipboard = function(text, btn) {
  navigator.clipboard.writeText(text).then(() => {
    const originalText = btn.textContent;
    btn.textContent = 'Copied!';
    setTimeout(() => {
      btn.textContent = originalText;
    }, 2000);
  }).catch(err => {
    console.error('Failed to copy: ', err);
  });
}

window.expandLines = function(btn, direction) {
  // This function retrieves hidden file content via API and dynamically inserts it into the diff table.
  // It also updates the 'gap row' to reflect the remaining hidden lines or removes it if fully expanded.
  const row = btn.closest('.gap-row');
  const file = row.dataset.file;
  let leftStart = parseInt(row.dataset.leftStart);
  let rightStart = parseInt(row.dataset.rightStart);
  let count = parseInt(row.dataset.count);
  const lang = row.dataset.lang;
  
  const urlParams = new URLSearchParams(window.location.search);
  const path = urlParams.get('path');
  const mode = window.location.pathname.includes('unstaged') ? 'unstaged' : 'committed';
  
  let fetchStart, fetchEnd, fetchCount;
  
  if (direction === 'down') {
    fetchCount = Math.min(20, count);
    fetchStart = rightStart;
    fetchEnd = fetchStart + fetchCount - 1;
  } else if (direction === 'up') {
    fetchCount = Math.min(20, count);
    fetchStart = rightStart + count - fetchCount;
    fetchEnd = rightStart + count - 1;
  } else { // all
    fetchCount = count;
    fetchStart = rightStart;
    fetchEnd = fetchStart + fetchCount - 1;
  }
  
  fetch(`/api/file_content?path=${encodeURIComponent(path)}&file=${encodeURIComponent(file)}&start=${fetchStart}&end=${fetchEnd}&mode=${mode}`)
    .then(res => res.json())
    .then(data => {
      const lines = data.lines;
      const newRows = [];
      
      lines.forEach((content, index) => {
        const lineNumRight = fetchStart + index;
        const lineNumLeft = leftStart + (lineNumRight - rightStart);
        
        const tr = document.createElement('tr');
        tr.className = 'line-row expanded-row';
        
        let html = '';
        // Left
        html += `<td class="ln">${lineNumLeft}</td>`;
        html += `<td class="unmodified">
          <div class="line-container">
            <div class="line-text-wrapper"><code class="${lang}">${content}</code></div>
          </div>
        </td>`;
        // Right
        html += `<td class="ln">${lineNumRight}</td>`;
        html += `<td class="unmodified">
          <div class="line-container">
            <div class="line-text-wrapper"><code class="${lang}">${content}</code></div>
          </div>
        </td>`;
        
        tr.innerHTML = html;
        newRows.push(tr);
      });
      
      if (direction === 'down' || direction === 'all') {
        newRows.forEach(tr => row.parentNode.insertBefore(tr, row));
      } else {
        // Insert after the gap row would be tricky if multiple, 
        // but for 'up', we insert before the gap row and then adjust the gap row's data.
        // Wait, if expanding UP, the new lines should appear ABOVE the hunk that follows.
        // The gap row is currently ABOVE the hunk that follows.
        // So 'up' expansion should insert lines AFTER the current gap row? No, 
        // if we have: [Hunk A] [Gap] [Hunk B]. 
        // Gap row is between A and B.
        // 'down' from A: lines appear above Gap row.
        // 'up' from B: lines appear below Gap row.
        newRows.reverse().forEach(tr => row.parentNode.insertBefore(tr, row.nextSibling));
      }
      
      // Update gap row
      if (direction === 'down') {
        row.dataset.leftStart = leftStart + fetchCount;
        row.dataset.rightStart = rightStart + fetchCount;
        row.dataset.count = count - fetchCount;
      } else if (direction === 'up') {
        row.dataset.count = count - fetchCount;
      } else {
        row.dataset.count = 0;
      }
      
      const newCount = parseInt(row.dataset.count);
      if (newCount <= 0) {
        row.remove();
      } else {
        const controls = row.querySelector('.gap-controls');
        if (newCount > 20) {
           controls.innerHTML = `
            <button class="expand-btn" onclick="expandLines(this, 'down')">▼ Expand 20 lines</button>
            <button class="expand-btn" onclick="expandLines(this, 'up')">▲ Expand 20 lines</button>
           `;
        } else {
           controls.innerHTML = `
            <button class="expand-btn" onclick="expandLines(this, 'all')">↕ Expand all ${newCount} lines</button>
           `;
        }
      }
      
      // Apply highlighting
      if (typeof hljs !== 'undefined') {
        newRows.forEach(tr => {
          tr.querySelectorAll('code').forEach(el => hljs.highlightElement(el));
        });
      }
    });
};
