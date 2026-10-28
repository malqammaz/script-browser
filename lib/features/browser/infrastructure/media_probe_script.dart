/// Runs in each frame and reports only sources attached to actual video elements.
const mediaProbeScript = r'''
(()=>{
  if(window.__scriptBrowserMediaProbe)return;
  window.__scriptBrowserMediaProbe=true;
  let scheduled=false;const watched=new WeakSet(),sent=new Set();
  function scan(){
    scheduled=false;
    for(const v of document.querySelectorAll('video')){
      if(!watched.has(v)){
        watched.add(v);
        for(const event of ['loadedmetadata','loadeddata','play','emptied'])v.addEventListener(event,schedule);
      }
      const source=v.currentSrc||v.src;
      if(!source||!window.flutter_inappwebview?.callHandler)continue;
      let url;try{url=new URL(source,location.href);}catch(_){continue;}
      if(!['http:','https:'].includes(url.protocol)||sent.has(url.href))continue;
      sent.add(url.href);
      window.flutter_inappwebview.callHandler('mediaDetected',{
        url:url.href,page:location.href,userAgent:navigator.userAgent
      }).catch(()=>sent.delete(url.href));
    }
  }
  function schedule(){if(!scheduled){scheduled=true;setTimeout(scan,200);}}
  new MutationObserver(schedule).observe(document,{subtree:true,childList:true,attributes:true,attributeFilter:['src']});
  window.addEventListener('flutterInAppWebViewPlatformReady',schedule);
  window.addEventListener('DOMContentLoaded',schedule);
  schedule();
})();
''';
