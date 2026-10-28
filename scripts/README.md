# سكربتات المواقع

كل دومين له مجلد مستقل، وداخله ملفات `.js`:

```text
scripts/
  example.com/
    click-button.js
    extract-links.js
    wait-and-click.js
  video.example.com/
    my-script.js
```

التطبيق يتعرف على دومين الصفحة المفتوحة ويجلب قائمة ملفاته من GitHub. `www.example.com` يستخدم مجلد `example.com`. النطاقات الفرعية الأخرى مستقلة. لا تكتب `https://` أو مسار الصفحة أو رقم المنفذ في اسم المجلد.

المجلد الافتراضي هو `scripts`. إذا غيّرته من التطبيق إلى مجلد آخر، ضع مجلدات الدومينات تحته. اختر المستودع والفرع مرة واحدة؛ قائمة السكربتات تظهر تلقائيًا عند اكتمال تحميل الموقع. زر التحديث يجلب قائمة جديدة من GitHub، واختيار ملف يجلب كوده من جديد. لا تُنفّذ الأكواد تلقائيًا.

ملف السكربت هو جسم دالة JavaScript async. يمكن استخدام `await` و`return`، ولا تضع صيغة `export` أو `import` الخاصة بوحدات ES. أرجع بيانات قابلة للتحويل إلى JSON لعرضها ونسخها في التطبيق.

```javascript
const button = document.querySelector('#download');
if (!button) throw new Error('Button not found');
button.click();
return {clicked: true};
```

الأمثلة تحتاج تعديل محدد العنصر حسب الموقع؛ موقع example.com لا يحتوي زر تنزيل. استخدم مثال استخراج الروابط لتجربة موقع example.com مباشرة.
