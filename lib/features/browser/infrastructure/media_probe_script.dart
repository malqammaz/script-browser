/// Inspects player sources inside each frame without fetching or decoding media.
const mediaProbeScript = r'''
(()=>{
  if(typeof window.__scriptBrowserMediaProbe==='function'){window.__scriptBrowserMediaProbe();return;}
  let scheduled=false;const watched=new WeakSet(),roots=new WeakSet(),sent=new Set();
  const marker='script-browser:scan-media:v1';
  function report(source,kind,type){
    if(!source||!window.flutter_inappwebview?.callHandler)return;
    let page;for(const candidate of [location.href,document.baseURI,document.referrer]){try{const u=new URL(candidate);if(['http:','https:'].includes(u.protocol)){page=u.href;break;}}catch(_){}}
    if(!page)return;
    let url;try{url=new URL(source,page);}catch(_){return;}
    if(!['http:','https:'].includes(url.protocol))return;
    if(kind==='resource'&&!/\.(mp4|m3u8)$/i.test(url.pathname))return;
    const key=kind+':'+url.href+':'+(type||'');
    if(sent.has(key)||sent.size>=120)return;
    sent.add(key);
    try{Promise.resolve(window.flutter_inappwebview.callHandler('mediaDetected',{
      url:url.href,page,userAgent:navigator.userAgent,kind,type:type||''
    })).catch(()=>sent.delete(key));}catch(_){sent.delete(key);}
  }
  const observer=new MutationObserver(schedule);
  function scan(){
    scheduled=false;
    if(location.hostname==='mega.nz'||location.hostname==='www.mega.nz')report(location.href,'preview');
    const queue=[document];let count=0;
    while(queue.length&&count++<64){
      const root=queue.shift();
      if(!roots.has(root)){roots.add(root);observer.observe(root,{subtree:true,childList:true,attributes:true,attributeFilter:['src']});}
      for(const v of root.querySelectorAll('video')){
        if(v.mediaKeys)continue;
        if(!watched.has(v)){
          watched.add(v);
          for(const event of ['loadedmetadata','loadeddata','play','emptied'])v.addEventListener(event,schedule);
        }
        report(v.currentSrc||v.src,'element');
        for(const source of v.querySelectorAll?v.querySelectorAll('source'):[])report(source.src,'element',source.type);
      }
      for(const node of root.querySelectorAll('*'))if(node.shadowRoot)queue.push(node.shadowRoot);
      for(const frame of root.querySelectorAll('iframe')){try{const u=new URL(frame.src,location.href);if(u.hostname==='mega.nz'||u.hostname==='www.mega.nz')report(u.href,'preview');}catch(_){}}
    }
    try{
      if(typeof window.jwplayer==='function')for(const item of window.jwplayer().getPlaylist()||[]){
        if(item.drm)continue;
        report(item.file,'player',item.type);
        for(const source of item.sources||[])if(!source.drm)report(source.file,'player',source.type);
      }
    }catch(_){}
    try{
      if(typeof window.videojs?.getPlayers==='function')for(const player of Object.values(window.videojs.getPlayers())){
        if(!player||player.eme)continue;
        for(const source of player.currentSources?player.currentSources():[])report(source.src,'player',source.type);
      }
    }catch(_){}
    try{for(const resource of performance.getEntriesByType('resource'))report(resource.name,'resource');}catch(_){}
  }
  function schedule(){if(!scheduled){scheduled=true;setTimeout(scan,200);}}
  window.__scriptBrowserMediaProbe=schedule;
  window.addEventListener('flutterInAppWebViewPlatformReady',schedule);
  window.addEventListener('DOMContentLoaded',schedule);
  window.addEventListener('message',event=>{
    if(event.data!==marker)return;
    // Explicit refresh retries previously reported sources and reaches cross-origin descendants.
    sent.clear();schedule();
    for(const frame of document.querySelectorAll('iframe'))try{frame.contentWindow.postMessage(marker,'*');}catch(_){}
  });
  try{new PerformanceObserver(schedule).observe({type:'resource',buffered:true});}catch(_){}
  schedule();
})();
''';
