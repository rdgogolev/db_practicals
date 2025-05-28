// static/index.js
window.onload = function() {
  const bookTable     = document.getElementById('book-table');
  const borrowSelect  = document.getElementById('borrowBookId');
  const borrowerInput = document.getElementById('borrowerName');
  const borrowForm    = document.getElementById('borrowForm');
  const returnSelect  = document.getElementById('returnBookId');
  const returnForm    = document.getElementById('returnForm');
  const clearBtn      = document.getElementById('clearDataBtn');

  // Load catalog
  fetch('/api/list')
    .then(r => r.json())
    .then(data => {
      bookTable.innerHTML   = '';
      borrowSelect .innerHTML = '<option value="">Select a book</option>';
      returnSelect.innerHTML = '<option value="">Select a book</option>';

      data.forEach(book => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
          <td>${book['Book ID']}</td>
          <td>${book['Title']}</td>
          <td>${book['Author']}</td>
          <td>${book['Publisher']}</td>
          <td>${book['Genre']}</td>
          <td>${book['Borrower'] || ''}</td>
          <td>${book['Borrow Date'] || ''}</td>
          <td>${book['Return Date'] || ''}</td>
          <td>${book['State']}</td>
        `;
        bookTable.appendChild(tr);

        const opt = document.createElement('option');
        opt.value = book['Book ID'];
        opt.textContent = `${book['Book ID']} – ${book['Title']}`;
        if (book['State'] === 'Present') {
          borrowSelect.appendChild(opt);
        } else {
          returnSelect.appendChild(opt);
        }
      });
    })
    .catch(err => {
      console.error(err);
      alert('Failed to load catalog.');
    });

  // Borrow
  borrowForm.addEventListener('submit', e => {
    e.preventDefault();
    const bookId = borrowSelect.value;
    const name   = borrowerInput.value.trim();
    if (!bookId || !name) return alert('Select a book and enter your name.');
    fetch(`/api/borrow?${new URLSearchParams({
      book_id:       bookId,
      borrower_name: name
    })}`, { method:'POST' })
      .then(r => r.ok ? location.reload() : Promise.reject(r.status))
      .catch(() => alert('Could not borrow the book.'));
  });

  // Return
  returnForm.addEventListener('submit', e => {
    e.preventDefault();
    const bookId = returnSelect.value;
    if (!bookId) return alert('Select a book to return.');
    fetch(`/api/return?${new URLSearchParams({ book_id: bookId })}`, { method:'POST' })
      .then(r => r.ok ? location.reload() : Promise.reject())
      .catch(() => alert('Could not return the book.'));
  });

  // Clear all
  clearBtn.addEventListener('click', () => {
    if (!confirm('Clear all borrow records?')) return;
    fetch('/api/totalreset', { method:'POST' })
      .then(r => r.json())
      .then(d => { alert(d.message); location.reload(); })
      .catch(() => alert('Could not clear data.'));
  });
};
