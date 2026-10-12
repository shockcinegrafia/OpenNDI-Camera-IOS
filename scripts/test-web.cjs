const fs=require('fs'),assert=require('assert'),acorn=require('acorn'),{JSDOM}=require('jsdom');
const dir='ios/OpenNDILegacy/';
const adapter=fs.readFileSync(dir+'legacy.js','utf8'); acorn.parse(adapter,{ecmaVersion:5});
for(const name of ['index_full','index_lite']) {
 const html=fs.readFileSync(dir+name+'.html','utf8');
 const scripts=Array.from(html.matchAll(/<script[^>]*>([\s\S]*?)<\/script>/g),m=>m[1]);
 scripts.forEach(s=>acorn.parse(s,{ecmaVersion:5}));
 const requests=[],timers=[],errors=[];
 let cap={mjpeg:true,remoteControls:true,switchCamera:true,zoom:true,zoomMin:1,zoomMax:3,focus:true,torch:false,darkScreen:true,resolutions:['AVCaptureSessionPreset640x480','AVCaptureSessionPreset1280x720'],frameRates:[15,30]};
 let state={capabilities:cap,currentZoom:1,isCameraEnabled:true,isTransmitting:false,isMicEnabled:false,isTorchEnabled:false,resolution:'AVCaptureSessionPreset640x480',fps:30};
 const dom=new JSDOM(html,{url:'http://camera:8088/',runScripts:'outside-only'}),w=dom.window;
 w.setInterval=(f)=>{timers.push(f);return timers.length;}; w.setTimeout=()=>1;
 w.XMLHttpRequest=function(){this.open=(method,url)=>this.url=url;this.send=()=>{requests.push(this.url);this.status=200;this.readyState=4;this.responseText=JSON.stringify(this.url.includes('/action?')?{ok:true,state}:state);if(this.onreadystatechange)this.onreadystatechange();};};
 scripts.forEach(s=>w.eval(s)); w.eval(adapter); if(name==='index_full')w.onload();
 assert(!requests.some(url=>/webrtc|live|layer|discovered/.test(url)),'No unsupported polling');
 const root=w.document.getElementById('camCard_0')||w.document.body;
 assert(root.textContent.includes('iOS Legacy 0.3.0'));
 if(name==='index_lite') { assert(w.document.getElementById('statusAud').textContent==='INDISPONÍVEL'); assert(w.document.getElementById('statusZoom').textContent==='1.0x'); }
 const torch=Array.from(root.querySelectorAll('button')).find(n=>(n.getAttribute('onclick')||'').includes('toggle_torch'));
 assert(torch.disabled,'Unsupported torch disabled');
 const dark=w.document.getElementById('legacyDark_0');assert(!dark.disabled);dark.click();assert(requests.some(url=>url.includes('type=toggle_dark_screen')));
 cap.torch=true;state.isTorchEnabled=true;timers.forEach(f=>f()); assert(!torch.disabled,'Available torch enabled');
 w.eval(torch.getAttribute('onclick'));assert(requests.some(url=>url.includes('type=toggle_torch')));
 if(name==='index_full')w.sendCmd(0,'/action/set_zoom?val=2');else w.sendCommand('set_zoom',2);
 assert(requests.some(url=>url.includes('type=set_zoom&value=2')),'Both action contracts normalized');
 const select=w.document.getElementById('legacyResolution_0');assert(select.options.length===2);select.value=cap.resolutions[1];select.dispatchEvent(new w.Event('change'));assert(requests.some(url=>url.includes('type=set_resolution')));
 const disabled=Array.from(root.querySelectorAll('button')).filter(n=>(n.getAttribute('onclick')||'').match(/toggle_record|toggleRecord|toggle_audio|toggle_gpu|toggle_transmission/));assert(disabled.length>0&&disabled.every(n=>n.disabled));
 console.log(name+': ES5 parse, initial render, capability gating, both action contracts, resolution, torch transitions: PASS');dom.window.close();
}

