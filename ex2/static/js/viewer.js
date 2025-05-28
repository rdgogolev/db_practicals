// static/viewer.js

window.onload = function () {
  const params   = new URLSearchParams(window.location.search);
  const table    = params.get('table');       // e.g. "Book"
  const pkName   = params.get('pk_name');     // e.g. "book_id"
  const pkValue  = params.get('pk_value');    // e.g. "3"

  const content = document.getElementById('content');
  if (table !== 'Book' || pkName !== 'book_id' || !pkValue) {
    content.innerHTML = '<p>Unsupported entity type or missing ID.</p>';
    return;
  }

  // Fetch the full list and find our book
  fetch('/api/list')
    .then(r => {
      if (!r.ok) throw new Error(r.statusText);
      return r.json();
    })
    .then(list => {
      const book = list.find(item => String(item['Book ID']) === pkValue);
      if (!book) {
        content.innerHTML = '<p>Book not found.</p>';
        return;
      }

      // Build details HTML
      let html = `<h1>${book['Title']}</h1><ul>
        <li><strong>ID:</strong> ${book['Book ID']}</li>
        <li><strong>Author:</strong> ${book['Author']}</li>
        <li><strong>Publisher:</strong> ${book['Publisher']}</li>
        <li><strong>Genre:</strong> ${book['Genre']}</li>
        <li><strong>State:</strong> ${book['Borrow Date'] ? 'Borrowed' : 'Present'}</li>`;

      if (book['Borrow Date']) {
        html += `
          <li><strong>Borrower:</strong> ${book['Borrower']}</li>
          <li><strong>Borrow Date:</strong> ${book['Borrow Date']}</li>
          <li><strong>Return Date:</strong> ${book['Return Date']}</li>`;
      }
      html += `</ul>
        <p><a href="./">← Back to catalog</a></p>`;

      content.innerHTML = html;

      // now load the Gemini description
      fetchGeminiDescription(book['Title']);
    })
    .catch(err => {
      console.error('Error loading book:', err);
      content.innerHTML = `<p>Error loading book details: ${err.message}</p>`;
    });
};

// pulls in your /api/description
async function fetchGeminiDescription(entityName) {
  try {
    const response = await fetch(
      `/api/description?name=${encodeURIComponent(entityName)}`
    );
    if (!response.ok) throw new Error(response.statusText);
    const data = await response.json();
    const md   = data.description || 'No description available.';
    const html = marked.parse(md);
    document
      .getElementById('content')
      .insertAdjacentHTML('beforeend', `<h2>Description</h2>${html}`);
  } catch (err) {
    console.error('Error fetching description:', err);
  }
}
