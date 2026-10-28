# Script Browser

![Browser icon](assets/branding/browser-icon.png)

## What's new in 1.6.0

- More room for websites: script output starts collapsed. Expand “نتيجة السكربت” to inspect/copy the result. Script controls hide while typing in the address bar.
- Simplified toolbar: Cast and ad protection stay visible. The overflow menu contains GitHub scripts, script editing, and library sync settings.
- Address bar accepts a website or Google search. `example.com` opens with HTTPS; `cats` or Arabic phrases search Google. Local addresses such as `http://192.168.1.10:8878/tv` work too. Enter/Go dismisses the keyboard. Back and Reload are beside the address field.
- The last completed HTTP/HTTPS page is stored locally, including its path/query/fragment, and restored when the app opens. The first launch (or invalid saved data) opens Google. Blank pages never replace the saved site. This is local browser history, not GitHub sync; URLs can contain sensitive query parameters.
- The built-in demonstration/test page has been removed from the app. Automated tests remain in the repository.
- Casting setup has three steps: choose TV, choose video, then connect. Video cards show host and stream type; long URLs are available under Details. Manual URLs and LG options are grouped under advanced options. Rescanning preserves the selected TV when it is still available.
- LG setup shows the receiver address with Copy and numbered instructions. Closing the dialog keeps casting active. A persistent session bar reopens controls or stops casting; the browser receiver reports playback state and cached media usage. DLNA state is not polled and is shown as a ready session.
- Loading, empty states, and connection failures have clearer messages and retry actions. Discovered quality is not guessed when the source does not supply it.
- New teal globe/code launcher icon, including Android adaptive and legacy density assets. Editable SVG and PNG preview live in `assets/branding/`.

### Architecture and SOLID review

- `BrowserSession` coordinates browsing and scripts using the `BrowserEngine` and `SettingsStore` interfaces; platform WebView and SharedPreferences adapters implement those contracts.
- `AddressResolver` owns URL/search interpretation independently of Flutter UI or persistence.
- `TvCast` owns device discovery and DLNA commands. `MediaRelay` now lives in its own file and owns scoped HTTP streaming, receiver endpoints, and RAM-prefetch coordination. Existing imports re-export the relay for compatibility.
- `RamMediaBuffer` owns bounded media storage and eviction independently of transport.
- Casting discovery is injectable, allowing widget tests without a real TV. `CastStatusBar` owns only status presentation and polling lifecycle; callers perform transport operations.
- This is an incremental separation of responsibilities, not a claim that every class has been fully redesigned. The cast dialog still coordinates its form state, and the relay still combines several HTTP concerns; future playback providers should use separate adapters rather than adding provider-specific branches throughout the UI.

### Validation and use

Run `flutter test`, `flutter analyze`, and `flutter build apk --debug`. Tests cover address/search encoding, last-page persistence/restoration and invalid state, collapsed results, a 360-pixel-wide casting flow, relay Range requests, HLS rewriting, the 128 MiB cache, seeking, and rate-limit handling. Live TV tests under `integration_test/` are optional and require a connected phone and TV; they are not built-in test pages.

For casting keep the app open and both devices on the same Wi-Fi. LG HLS uses the TV browser receiver. Public Google Drive links use Google's own preview player on the TV. RAM prefetch applies only to supported HLS VOD segments; it cannot guarantee uninterrupted playback. Existing token storage and scoped cookie forwarding are unchanged.

---

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

Validation for this revision: 52 automated tests passed; flutter analyze reported no issues; Android debug APK built successfully. Live TV playback was not repeated for this UI revision.

## Seek recovery (1.6.1)

A live LG session stalled at 12:26.7 after seeking despite approximately 47 MiB in the phone cache, HTTP 200 from the source, and no recorded relay error. Those observations do not establish the decoder's root cause. The TV receiver now reports seeking/buffering separately from playing and reports backward seeks correctly. If playback makes no progress for 15 seconds while unpaused, it attempts one reload at the same time. A visible Retry playback button allows an explicit further attempt. This avoids an unbounded automatic reload loop and does not change upstream rate-limit handling. Google Drive's embedded player is unchanged.

Run `node test/receiver_player_test.cjs` to verify the receiver's recovery limit, position preservation, backward-seek reporting, and progress handling with a simulated video element. Real LG playback still requires a manual TV test after updating and reloading the receiver page.

## Embedded and extensionless videos (1.6.2)

Live diagnosis found Yalanime's Dood FHD player in a cross-origin iframe redirecting from dood.to to playmogo.com. Its active video source was an HTTPS CDN URL without an MP4/M3U8 extension. The previous top-page/extension detector missed it.

A small script now observes video elements in every frame. It reports an actual network currentSrc/src, the frame's referrer, and user agent to the native media catalog. Sources are deduplicated, and source changes are observed. Extensionless arbitrary resource requests are still excluded; blob/data/javascript URLs are not castable. This does not bypass DRM, login, host restrictions, or expired links. Some hosts may still reject TV playback even when detected successfully. Installing the update requires reloading the site so the frame observer is injected.

Run `node test/media_probe_test.cjs` for extensionless video reporting, per-frame referrer, deduplication, source changes, and blob rejection. Dart media-source tests cover explicit video evidence and URL filtering.

Live validation on the connected phone: after installing 1.6.2, selected Dood FHD and pressed Play on the supplied Yalanime episode. The native media catalog contained one detected source from cloudatacdn.com. Dood TV playback was not validated by this detection test. All 53 Flutter tests and the JavaScript frame-probe tests passed; static analysis reported no issues.

## English UI and scripts dock (1.6.3)

The app interface, launcher label, dialogs, tooltips, status messages, and application errors now use English with left-to-right layout. Website content, user-authored scripts, existing saved script names, scraped anime titles, and Arabic data-normalization rules remain as supplied.

The Scripts workspace has a down arrow in its upper-right corner. Tap it to minimize the entire site-script selector, Run controls, and output area into a compact Scripts header. Tap the up arrow to restore it. Minimizing does not stop a running script or clear its output, and the header shows when a script is running. The nested output expander keeps its state when the dock is minimized.

A widget regression test verifies minimize/restore controls and preserved expanded output.

Validation: 54 Flutter tests passed, both JavaScript detector/player test suites passed, and flutter analyze reported no issues.

## LG HLS MSE player (1.6.4)

Live Uqload diagnostics showed successful HTTP 200 segment responses, usually below one second, while the LG native HLS receiver repeatedly entered buffering. The phone video was paused during inspection. This points to the native playback path, but is not proof of a single root cause.

For HLS receiver pages, the TV now prefers bundled HLS.js 1.7.3 when MediaSource Extensions are supported, with native playback as a compatibility fallback. MPEG-TS segments are transmuxed for MSE rather than relying solely on native HLS handling. The TV targets a 60-second forward buffer (maximum 120 seconds, 32 MiB buffer-size target) and retains 20 seconds behind; actual allocation depends on the browser. The separate phone cache retains its existing 128 MiB limit. Phone status now reports actual forward buffered seconds from the TV, alongside RAM cache usage. The retry button rebuilds the player at the current time.

The library is served locally from the phone at a TV-IP-restricted endpoint. It is not fetched from a CDN at playback time. Upstream cookie scoping, cache limits, and rate-limit handling remain in place. Drive preview embedding is unchanged.

Bundled upstream: https://www.npmjs.com/package/hls.js/v/1.7.3, Apache-2.0 license in `assets/vendor/hls-LICENSE.txt`. The npm tarball was verified against the registry SHA-512 integrity value. SHA-256 of `hls-1.7.3.min.js`: `a12e7ee1cd64a69dcdb314157e45dafcba705bfb0b1440b7935cb265d374423e`.

References: https://github.com/video-dev/hls.js and https://webostv.developer.lge.com/develop/specifications/streaming-protocol-drm. Node receiver tests cover MSE selection, reported TV buffer, and recovery position. Relay tests cover the bundled script endpoint and receiver telemetry. LG playback must be verified after installing and refreshing the receiver.
