# متصفح السكربتات — Flutter لأندرويد

متصفح يشغّل ملفات JavaScript من GitHub على الصفحة المفتوحة، مع حماية محلية من الإعلانات والتتبع والنوافذ الجديدة.

كود التطبيق في مستودع خاص. مستودع السكربتات العام الافتراضي هو [script-browser-scripts](https://github.com/malqammaz/script-browser-scripts)، ويمكن تغييره من إعدادات GitHub في التطبيق. الإعدادات المحفوظة سابقًا لا يتم استبدالها.

## الاستخدام

1. افتح الموقع من شريط العنوان.
2. اضغط أيقونة GitHub وأدخل المستودع بالشكل `owner/repo`، والفرع (افتراضيًا `main`)، ومجلد السكربتات الجذر (افتراضيًا `scripts`).
3. التطبيق يتعرف على الدومين تلقائيًا، ويبحث داخل `scripts/<domain>/`.
4. اضغط شريط السكربتات أسفل الصفحة، اختر الملف، راجع الكود واحفظه، ثم اضغط تشغيل.
5. تظهر النتيجة أسفل الصفحة ويمكن نسخها. زر تحديث السكربتات يجلب آخر قائمة من GitHub.

```text
scripts/
  example.com/
    click-button.js
    extract-links.js
  video.example.com/
    player.js
```

`www.example.com` يستخدم مجلد `example.com`. النطاقات الفرعية الأخرى مستقلة. المنفذ ومسار الصفحة لا يدخلان في اسم المجلد. عند الانتقال إلى موقع مختلف، لا يُسمح بتشغيل سكربت تم اختياره للموقع السابق.

المستودع الذي يحتوي السكربتات يجب أن يكون عامًا حاليًا، ويمكن أن يكون منفصلًا عن مستودع التطبيق. لا يوجد تشغيل تلقائي للسكربتات. ملفات الأمثلة موجودة تحت `scripts/example.com/`؛ مثال استخراج الروابط يعمل على موقع example.com، ومثال الضغط يحتاج تعديل محدد الزر حسب الموقع.

## صيغة JavaScript

```javascript
const button = document.querySelector('#download');
if (!button) throw new Error('Button not found');
button.click();
return {clicked: true};
```

الملف يُنفّذ داخل دالة async؛ يمكن استخدام `await` و`return`. استخدم قيمًا قابلة للتحويل إلى JSON. راجع [دليل السكربتات](scripts/README.md) للتفاصيل.

## حماية الإعلانات

اضغط الدرع للتحكم في الحماية العامة، أو استثناء الموقع الحالي، أو إضافة نطاقات حظر مخصصة. الإعدادات تُحفظ محليًا، والحفظ يعيد تحميل الصفحة. القائمة المدمجة محلية ومحدودة، وتجمع حظر نطاقات الإعلان والتتبع والنوافذ الجديدة مع إخفاء علامات إعلان معروفة. ليست نظام تعلم آلي أو اشتراك EasyList، وقد تفلت بعض الإعلانات.

## التطوير والبناء

استخدم Flutter 3.47.8 مع Android SDK وJava 17 أو 21:

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d DEVICE_ID
flutter build apk --debug
```

الناتج: `build/app/outputs/flutter-apk/app-debug.apk`. نسخة debug للتجربة؛ النشر يتطلب توقيع release خاصًا بك. GitHub Actions يفحص التنسيق والتحليل والاختبارات ويبني APK، ويمكن تنزيله من Artifacts بعد نجاحه.

- [بنية المشروع وحدود المسؤوليات](docs/ARCHITECTURE.md)
- [إعداد البيئة والاختبارات والعمل مع Git](docs/DEVELOPMENT.md)
- [إضافة سكربتات لكل موقع](scripts/README.md)

`main.dart` لتجهيز التطبيق فقط. الكود موزع على ميزات `browser` و`scripts` و`protection`، مع فصل الواجهات عن إدارة الحالة والتخزين والاتصال بـGitHub. الإعدادات القديمة تبقى متوافقة بعد التحديث.

## حدود النسخة

- Android 7 / API 24 فأحدث، وأجهزة أندرويد فقط.
- السكربت يعمل بصلاحيات الصفحة؛ قيود المتصفح تنطبق على iframes والنقرات التي تتطلب تفاعلًا فعليًا.
- مهلة انتظار النتائج 30 ثانية، ولا توقف حلقة JavaScript متزامنة لا نهائية.
- لا يوجد رفع JSON إلى GitHub أو تنزيل ملفات أو نوافذ متعددة بعد.
- GitHub قد يحد الطلبات دون تسجيل دخول. قوائم الملفات مخزنة مؤقتًا أثناء الجلسة؛ التحديث يتجاوز التخزين المؤقت، وكود الملف يُجلب من جديد عند اختياره.
- InAppWebView مثبت على `6.2.0-beta.3` لإصلاح توافق ProGuard مع AGP 9، وتحديثه يحتاج إعادة اختبارات الهاتف.

## مزامنة المكتبة من التطبيق

في الإصدار 1.3.0 افتح زر «مزامنة مكتبة الأنمي» (السحابة مع سهم للأعلى)، وأدخل Fine-grained GitHub token بصلاحية Contents: Read and write لمستودع malqammaz/anime-library فقط. يتم تخزينه مشفراً بواسطة flutter_secure_storage، ولا يمر إلى JavaScript أو WebView.

افتح صفحة الأنمي على yalanime.com، حدّث قائمة السكربتات واختر sync-anime-library.js واضغط تشغيل. بعد السحب، التطبيق يقرأ library.json من فرع main ويدمج الحلقات والروابط ويرفع التعديل تلقائياً. لا تحتاج نسخ JSON أو فتح GitHub. يستطيع المستخدم إيقاف المزامنة وحذف التوكن من نفس نافذة الإعداد.

التطبيق لا يرفع نتائج السكربتات الأخرى تلقائياً. تبقى نتيجة السحب ظاهرة إذا فشل الرفع، ولا ينشئ commit عند عدم وجود تغيير. في حال التعارض يعيد قراءة الملف والدمج مرة واحدة.

## بث الفيديو إلى تلفزيون LG / DLNA (1.4.0)

افتح صفحة المشاهدة وشغّل الفيديو أولاً، ثم اضغط أيقونة Cast في الأعلى. اختر التلفزيون ورابط الفيديو ثم «بث». يوجد إيقاف مؤقت واستئناف وإيقاف كامل، ويمكن إدخال رابط MP4 أو M3U8 مباشر يدوياً.

الجهازان يجب أن يكونا على نفس Wi-Fi. أبقِ التطبيق مفتوحاً أثناء البث؛ لم تُضف خدمة تشغيل في الخلفية بعد. التطبيق يرسل البيانات عبر خادم محلي مؤقت محدود بالتلفزيون المحدد ومسارات عشوائية، بدون حفظ ملف الفيديو كاملاً. يدعم طلبات Range للفيديو وإعادة كتابة روابط قوائم HLS والملفات التابعة. كوكيز مصدر الفيديو تُقرأ في التطبيق وترسل للمصدر فقط، ولا تُرسل إلى التلفزيون أو GitHub.

اكتشاف الروابط يعتمد على طلبات الشبكة MP4/M3U8 وروابط عناصر الفيديو؛ الروابط المشفرة أو blob بدون قائمة ظاهرة وDRM ليست مضمونة. أعد تحميل الصفحة وشغّل الفيديو إن لم يظهر بالقائمة. لا يغيّر البث إعداد حظر الإعلانات.

اختبار Relay وSOAP: flutter test test/tv_cast_test.dart
اختبار فعلي على الهاتف والتلفزيون: flutter test integration_test/tv_cast_test.dart -d DEVICE_ID

### نتيجة اختبار Yalanime على LG UR78006LL

اختبار فعلي بتاريخ 2026-10-28: تم اكتشاف HLS من Uqload وVidara؛ رفض التلفزيون تحميله عبر DLNA (SetAVTransportURI 716/701). قائمة الصيغ المعلنة من التلفزيون لا تذكر HLS. تشغيل MP4 التجريبي من الهاتف نجح سابقاً؛ نجاح HLS من هؤلاء المضيفين غير مؤكد ولا يعد ميزة متحققة على هذا التلفزيون. تحسين 1.4.1 يقرأ مصادر JW Player المعلنة قبل بدء طلب الفيديو، ويحاول إيقاف جلسة التلفزيون عند فشل التحميل.

اختبار الموقع الحي اختياري: flutter test integration_test/yalanime_cast_test.dart -d DEVICE_ID. يتطلب تلفزيون LG وشبكة محلية وخوادم فيديو متاحة، وسيحاول بدء تشغيل فيديو على التلفزيون.

## LG browser receiver (1.5.0)

بالنسبة لروابط HLS على LG، خيار «استخدام متصفح LG لبث HLS» يجهز صفحة تشغيل محلية بدلاً من تحميل الفيديو عبر DLNA. بعد ضغط «بث»، افتح العنوان المعروض في Web Browser على التلفزيون (مثل http://PHONE_IP:8878/tv) واضغط Play. يمكن حفظ العنوان في مفضلة التلفزيون ما دام عنوان الهاتف على Wi-Fi ثابتاً. التحكم بالصوت والإيقاف المؤقت يتم من مشغل التلفزيون؛ «إيقاف البث» في الهاتف يغلق Relay.

صفحة /tv متاحة فقط لعنوان التلفزيون المحدد، ولا تحتوي على كوكيز أو توكن GitHub. الهاتف يبقى مفتوحاً على التطبيق وعلى نفس الشبكة. لا يتم تثبيت تطبيق على التلفزيون ولا تغيير إعدادات التلفزيون أو الشهادات.

التحقق الفعلي 2026-10-28: نجح تشغيل حلقة Overgeared من Yalanime/Vidara عبر متصفح LG UR78006LL. سجلت صفحة الاستقبال playing وتقدماً إلى 4.319 ثانية، وأكد المستخدم ظهور الفيديو على التلفزيون. هذا تحقق لمسار المتصفح، وليس إصلاحاً لدعم HLS في DLNA.

## معاينة Google Drive العامة (1.5.1)

افتح رابط الفيديو العام من Drive داخل المتصفح، ثم Cast واختر بطاقة drive.google.com. أو الصق رابط الملف العام في حقل الرابط اليدوي. مع تفعيل «استخدام متصفح LG للفيديو»، افتح العنوان المحلي المعروض على LG واضغط Play في مشغل Google.

يتم تضمين صفحة Drive /preview الأصلية على التلفزيون؛ لا يتم استخراج أو تنزيل الملف الأصلي، ولا قبول تحذير فحص الفيروسات، ولا استخدام حساب Google أو OAuth. تشغيل المعاينة ينقل بيانات الفيديو كالمعتاد إلى مشغل المعاينة، وقد يستخدم المتصفح تخزيناً مؤقتاً. لا يعد هذا فحص أمان للمحتوى. إذا تعذرت المعاينة لا يوجد fallback تلقائي إلى download/confirm.

التجربة الفعلية على الملف العام المقدم: أكد المستخدم عمل الصورة والصوت على LG. محاولة نسخ رابط تدفق Drive الخام لم تنجح لأن المشغل يستخدم yt-ump ومسارات فيديو وصوت منفصلة؛ يحتفظ التطبيق بخيار صفحة المعاينة لتجنب هذه المشكلة.

## RAM buffer (1.5.2)

Supported HLS VOD playlists now prefetch sequential segments, keeping at most 128 MiB of media bytes in phone RAM and looking roughly 120 seconds ahead. Old segments are discarded as playback advances; seeking reprioritizes the new position. The TV player displays current buffer usage. No video files are written by this buffer. Total app memory can exceed the cache limit, and Android may reclaim the app under memory pressure.

Prefetch uses one request at a time, a short delay, a 16 MiB per-segment limit, and stops on a failed request. HTTP 429/503 pauses prefetch according to Retry-After (at least 30 seconds). These limits cannot guarantee uninterrupted playback or prevent a host from restricting requests.

Live HLS, byte-range playlists, and direct MP4 continue through the normal relay. Google Drive preview plays directly on the TV and does not use this phone cache. Keep the app open while casting.

Validation: flutter test test/ram_media_buffer_test.dart covers memory limits, cached Range requests, seeking, and rate-limit handling with a local test server.
