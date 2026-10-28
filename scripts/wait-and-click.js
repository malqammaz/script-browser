const selector = 'button';
const deadline = Date.now() + 10000;
while (!document.querySelector(selector)) {
  if (Date.now() > deadline) throw new Error('Button did not appear');
  await new Promise(resolve => setTimeout(resolve, 200));
}
document.querySelector(selector).click();
return 'Clicked';
