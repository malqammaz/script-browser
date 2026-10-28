return Array.from(document.querySelectorAll('a[href]'), link => ({
  text: link.textContent.trim(),
  url: link.href
}));
