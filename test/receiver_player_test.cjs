const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const dart=fs.readFileSync('lib/features/browser/application/receiver_player_script.dart','utf8');
const script=dart.match(/r'''([\s\S]*?)'''/)[1];
let now=0,interval,loads=0;const handlers={},reports=[];
const video={currentTime:746.7,readyState:2,seeking:false,paused:false,ended:false,error:null,addEventListener:(n,f)=>handlers[n]=f,play:()=>Promise.resolve(),load:()=>loads++};
const status={textContent:''},retry={addEventListener:(_,f)=>retry.click=f};
vm.runInNewContext(script,{document:{getElementById:id=>id==='video'?video:id==='status'?status:retry},Date:{now:()=>now},Number,Math,fetch:url=>{reports.push(url);return Promise.resolve({json:()=>Promise.resolve({used:0,limit:134217728})});},setInterval:f=>interval=f});
handlers.seeking();handlers.waiting();now=16000;interval();assert.equal(loads,1);
handlers.loadedmetadata();assert.equal(video.currentTime,746.7);
now=33000;interval();assert.equal(loads,1,'Only one automatic recovery per seek');
retry.click();assert.equal(loads,2,'Explicit retry remains available');
video.currentTime=800;handlers.timeupdate();video.currentTime=100;handlers.seeking();handlers.timeupdate();
assert(reports.some(x=>x.includes('state=seeking&time=100')),'Backward seeks must report current position');
video.readyState=4;video.currentTime=101;handlers.timeupdate();now=34000;interval();assert.equal(loads,2,'Progress must prevent recovery');
console.log('Receiver recovery tests passed');
// MSE initialization and recovery use the selected time rather than native reload.
{
  const instances=[],listeners={},events=[],timers=[];let destroyed=0;
  class HlsMock {
    static Events={MANIFEST_PARSED:'manifest',ERROR:'error'};
    static isSupported(){return true;}
    constructor(config){this.config=config;instances.push(this);}
    on(){} loadSource(url){this.url=url;} attachMedia(v){this.media=v;} destroy(){destroyed++;}
  }
  const video={currentTime:740,readyState:4,paused:false,ended:false,error:null,buffered:{length:1,start:()=>730,end:()=>780},getAttribute:n=>n==='data-hls'?'true':'http://phone/private/master.m3u8',addEventListener:(n,f)=>listeners[n]=f,play:()=>Promise.resolve(),load:()=>{throw Error('Native load must not be used for MSE');}};
  const retry={addEventListener:(_,f)=>retry.click=f};
  vm.runInNewContext(script,{Hls:HlsMock,document:{getElementById:id=>id==='video'?video:id==='retry'?retry:{textContent:''}},Date:{now:()=>0},Number,Math,fetch:url=>{events.push(url);return Promise.resolve({json:()=>Promise.resolve({used:0,limit:134217728})});},setInterval:f=>timers.push(f)});
  assert.equal(instances.length,1);assert.equal(instances[0].config.maxBufferSize,33554432);
  listeners.playing();assert(events.some(u=>u.includes('engine=hlsjs&ahead=40&ready=4')));
  retry.click();assert.equal(destroyed,1);assert.equal(instances[1].config.startPosition,740);
  console.log('HLS MSE receiver tests passed');
}
