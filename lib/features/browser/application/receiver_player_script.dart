/// Native TV-player lifecycle and bounded recovery; no upstream URLs or credentials.
const receiverPlayerScript = r'''
const v=document.getElementById('video'),s=document.getElementById('status'),retry=document.getElementById('retry');
let last=0,lastPosition=0,lastProgress=Date.now(),retries=0,recovering=false,resumeAt=null;
function report(state){fetch('/tv-status?state='+state+'&time='+v.currentTime).catch(()=>{});}
function recover(){
  resumeAt=Number.isFinite(v.currentTime)?v.currentTime:lastPosition;
  recovering=true;retries++;lastPosition=resumeAt;lastProgress=Date.now();
  s.textContent='Reloading stream at the same position…';report('recovering');
  v.load();
}
retry.addEventListener('click',recover);
v.addEventListener('loadedmetadata',()=>{
  if(resumeAt!==null){const target=resumeAt;resumeAt=null;try{v.currentTime=target;}catch(_){s.textContent='Select the desired time and press Play.';}}
  v.play().catch(()=>{s.textContent='Press Play to continue.';});
});
v.addEventListener('seeking',()=>{
  if(!recovering)retries=0;
  lastProgress=Date.now();last=v.currentTime;
  s.textContent='Seeking…';report('seeking');
});
v.addEventListener('waiting',()=>{s.textContent='Buffering…';report('buffering');});
v.addEventListener('stalled',()=>{s.textContent='Waiting for video data…';report('buffering');});
v.addEventListener('playing',()=>{s.textContent='Playing from your phone';report('playing');});
v.addEventListener('pause',()=>report('paused'));
v.addEventListener('ended',()=>report('ended'));
v.addEventListener('error',()=>{s.textContent='Unable to play this stream. Select Retry to resume.';report('error');});
v.addEventListener('timeupdate',()=>{
  if(Math.abs(v.currentTime-lastPosition)>.15){lastProgress=Date.now();lastPosition=v.currentTime;recovering=false;}
  if(Math.abs(v.currentTime-last)>2){last=v.currentTime;report(v.seeking?'seeking':v.readyState<3?'buffering':'playing');}
});
v.play().catch(()=>{s.textContent='Press Play on the video to start.';});
setInterval(()=>{
  if(!v.paused&&!v.ended&&!v.error&&Date.now()-lastProgress>15000){
    if(retries<1)recover();
    else {s.textContent='Playback is stuck. Select Retry to reload at this time.';report('buffering');}
  }
  if(!v.paused&&!v.error&&v.readyState>=3&&!v.seeking&&!recovering){
    fetch('/tv-buffer').then(r=>r.json()).then(b=>{if(v.readyState>=3&&!v.seeking&&!recovering)s.textContent='Playing · RAM buffer '+(b.used/1048576).toFixed(1)+' / '+(b.limit/1048576).toFixed(0)+' MB';}).catch(()=>{});
  }
},4000);
''';
