// Change this selector to match the button on your site.
const selector = 'button';
const button = document.querySelector(selector);
if (!button) throw new Error(`Button not found: ${selector}`);
button.scrollIntoView({block: 'center'});
button.click();
return {clicked: true, text: button.textContent.trim()};
