const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync('lib/features/browser/infrastructure/media_probe_script.dart','utf8').match(/r'''([\s\S]*?)'''/)[1];
const calls=[],queue=[],handlers={};let changed;
const video={currentSrc:'https://cdn.example/opaque~signed?token=abc',src:'',addEventListener:(n,f)=>handlers[n]=f};
const context={document:{querySelectorAll:()=>[video]},location:{href:'https://player.example/e/123'},navigator:{userAgent:'Test phone'},URL,WeakSet,Set,setTimeout:f=>queue.push(f),MutationObserver:class{constructor(f){changed=f;}observe(){}},window:{addEventListener:()=>{},flutter_inappwebview:{callHandler:(name,data)=>{calls.push({name,data});return Promise.resolve();}}}};
vm.runInNewContext(source,context);queue.splice(0).forEach(f=>f());
assert.equal(calls.length,1);assert.equal(calls[0].data.url,video.currentSrc);assert.equal(calls[0].data.page,'https://player.example/e/123');
changed();queue.splice(0).forEach(f=>f());assert.equal(calls.length,1,'Deduplicates the same video source');
video.currentSrc='https://cdn.example/new-source';handlers.loadedmetadata();queue.splice(0).forEach(f=>f());assert.equal(calls.length,2);
video.currentSrc='blob:https://player.example/local';changed();queue.splice(0).forEach(f=>f());assert.equal(calls.length,2,'Does not send non-network blob URLs to the relay');
console.log('Frame media probe tests passed');
// Nested sources, shadow DOM, iframe JW configuration, late resource discovery and explicit refresh.
{
 const sent=[],tasks=[],events={},forwarded=[];
 const nested={src:'https://cdn.example/nested.mp4',type:'video/mp4'};
 const blobVideo={currentSrc:'blob:https://player.example/opaque',src:'',addEventListener(){},querySelectorAll:()=>[nested]};
 const shadowVideo={currentSrc:'https://cdn.example/shadow-stream',src:'',addEventListener(){},querySelectorAll:()=>[]};
 const shadow={querySelectorAll:s=>s==='video'?[shadowVideo]:[]};
 const root={querySelectorAll:s=>s==='video'?[blobVideo]:s==='*'?[{shadowRoot:shadow}]:s==='iframe'?[{contentWindow:{postMessage:(...args)=>forwarded.push(args)}}]:[]};
 const context={document:root,location:{href:'https://hanerix.example/e/123'},navigator:{userAgent:'Phone'},URL,WeakSet,Set,Promise,performance:{getEntriesByType:()=>[{name:'https://cdn.example/adaptive.m3u8'},{name:'https://cdn.example/metrics.txt'}]},setTimeout:f=>tasks.push(f),MutationObserver:class{observe(){}},window:{addEventListener:(name,f)=>events[name]=f,jwplayer:()=>({getPlaylist:()=>[{sources:[{file:'https://cdn.example/manifest.txt',type:'hls'}]},{drm:{},file:'https://cdn.example/protected.mp4'}]}),flutter_inappwebview:{callHandler:(_,data)=>{sent.push(data);return Promise.resolve();}}}};
 vm.runInNewContext(source,context);tasks.splice(0).forEach(f=>f());
 assert(sent.some(x=>x.url===nested.src));assert(sent.some(x=>x.url===shadowVideo.currentSrc));
 assert(sent.some(x=>x.url.endsWith('/manifest.txt')&&x.type==='hls'&&x.kind==='player'));
 assert(sent.some(x=>x.url.endsWith('/adaptive.m3u8')));
 assert(!sent.some(x=>/metrics|protected|blob:/.test(x.url)));
 const before=sent.length;events.message({data:'script-browser:scan-media:v1'});tasks.splice(0).forEach(f=>f());
 assert.equal(sent.length,before*2);assert.equal(forwarded.length,1);
 console.log('Embedded player configuration and refresh tests passed');
}
// A bridge becoming ready late must not permanently hide a srcdoc frame's video.
{
 const calls=[],queue=[],events={};let ready=false;
 const video={currentSrc:'https://cdn.example/iframe-video.mp4',src:'',addEventListener(){},querySelectorAll:()=>[]};
 const doc={baseURI:'https://embed.example/player',querySelectorAll:s=>s==='video'?[video]:[]};
 const context={document:doc,location:{href:'about:srcdoc'},navigator:{userAgent:'Phone'},URL,WeakSet,Set,Promise,setTimeout:f=>queue.push(f),MutationObserver:class{observe(){}},window:{addEventListener:(n,f)=>events[n]=f,flutter_inappwebview:{callHandler:(_,data)=>{if(!ready)throw Error('Bridge not ready');calls.push(data);return Promise.resolve();}}}};
 vm.runInNewContext(source,context);queue.splice(0).forEach(f=>f());assert.equal(calls.length,0);
 ready=true;events.flutterInAppWebViewPlatformReady();queue.splice(0).forEach(f=>f());
 assert.equal(calls.length,1);assert.equal(calls[0].page,doc.baseURI);
 console.log('Late bridge and srcdoc frame tests passed');
}
// Public MEGA embeds are offered as previews, not as encrypted byte streams.
{
 const calls=[],tasks=[];const key='A'.repeat(43);
 const iframe={src:'https://mega.nz/embed/AbCd1234#'+key};
 const context={document:{querySelectorAll:s=>s==='iframe'?[iframe]:[]},location:{href:'https://example.com/watch',hostname:'example.com'},navigator:{userAgent:'Phone'},URL,WeakSet,Set,Promise,setTimeout:f=>tasks.push(f),MutationObserver:class{observe(){}},window:{addEventListener(){},flutter_inappwebview:{callHandler:(_,data)=>{calls.push(data);return Promise.resolve();}}}};
 vm.runInNewContext(source,context);tasks.splice(0).forEach(f=>f());
 assert.equal(calls.length,1);assert.equal(calls[0].kind,'preview');assert(calls[0].url.endsWith('#'+key));
 console.log('MEGA public iframe detection test passed');
}
