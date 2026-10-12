/* ES5 adapter: preserve the Android Full/Lite panels, expose only real iOS controls. */
(function () {
    var full = typeof cameras !== 'undefined';
    var states = {}, pending = {};
    function base(idx) { return full ? (cameras[idx] || '') : getBaseUrl(); }
    function request(idx, path, done) {
        var xhr = new XMLHttpRequest();
        xhr.open('GET', base(idx) + path, true); xhr.timeout = 5000;
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== 4) return;
            var data; try { data = JSON.parse(xhr.responseText); } catch (e) { data = {error:'Resposta inválida'}; }
            done(data, xhr.status);
        };
        xhr.onerror = xhr.ontimeout = function () { done({error:'Câmera sem resposta'}, 0); };
        xhr.send();
    }
    function message(idx, text) {
        var node = document.getElementById('legacyMessage_' + idx);
        if (node) node.textContent = text;
    }
    function command(idx, type, value) {
        request(idx, '/action?type=' + encodeURIComponent(type) + (value === undefined ? '' : '&value=' + encodeURIComponent(value)), function (data,status) {
            message(idx, data.ok ? 'Aplicado' : (data.error || ('HTTP ' + status)));
            if (data.state) apply(idx,data.state);
            else poll(idx);
        });
    }
    function decodeAction(handler) {
        var match = /\/action\/([^'"?]+)(?:\?val=([^'"&]+))?/.exec(handler);
        if (match) return {type:match[1],value:match[2]};
        match = /sendCommand\('([^']+)'/.exec(handler);
        return match ? {type:match[1]} : null;
    }
    function supported(action, cap) {
        if (!action) return false;
        var type = action.type;
        if (/^zoom_/.test(type)) {
            var number = type === 'zoom_05' ? 0.5 : parseFloat(type.substr(5));
            return cap.zoom && number >= cap.zoomMin && number <= cap.zoomMax;
        }
        return type === 'toggle_camera_power' || (type === 'toggle_camera' && cap.switchCamera) || (type === 'toggle_torch' && cap.torch);
    }
    function panel(idx, root) {
        var node = document.getElementById('legacyPanel_' + idx);
        if (node) return node;
        node = document.createElement('div'); node.id = 'legacyPanel_' + idx; node.className = 'legacy-panel';
        node.innerHTML = '<b>iOS Legacy 0.3.0 · MJPEG (sem áudio)</b><br><button id="legacyDark_' + idx + '">Tela escura</button> <label>Resolução <select id="legacyResolution_' + idx + '"></select></label> <label>FPS <select id="legacyFPS_' + idx + '"></select></label><p id="legacyMessage_' + idx + '">Aguardando câmera…</p><small>NDI, áudio, gravação, GPU, RTMP e Studio indisponíveis no iOS Legacy.</small>';
        root.insertBefore(node,root.firstChild);
        document.getElementById('legacyDark_' + idx).onclick = function () { command(idx,'toggle_dark_screen'); };
        document.getElementById('legacyResolution_' + idx).onchange = function () { command(idx,'set_resolution',this.value); };
        document.getElementById('legacyFPS_' + idx).onchange = function () { command(idx,'set_fps',this.value); };
        return node;
    }
    function options(node, values, selected) {
        var signature = values.join('|');
        if (node.getAttribute('data-options') !== signature) {
            node.innerHTML = '';
            for (var i=0;i<values.length;i++) { var option=document.createElement('option'); option.value=values[i]; option.textContent=String(values[i]).replace('AVCaptureSessionPreset',''); node.appendChild(option); }
            node.setAttribute('data-options',signature);
        }
        node.disabled = values.length < 2; node.value = String(selected);
    }
    function gate(idx, cap) {
        var root = full ? document.getElementById('camCard_' + idx) : document.body;
        if (!root) return;
        var nodes = root.querySelectorAll('button,input,select,a');
        for (var i=0;i<nodes.length;i++) {
            var node=nodes[i], handler=(node.getAttribute('onclick') || '') + ' ' + (node.getAttribute('onchange') || '') + ' ' + (node.getAttribute('oninput') || '');
            if (/^legacy/.test(node.id)) continue;
            var action=decodeAction(handler);
            var unavailable = action ? !supported(action,cap) : /sendSlider|toggleRecord|toggleAllRecords|Live|Layout|Overlay|LowerThird|Gallery|Media|Studio|WebRtc|testWebRtc/.test(handler);
            if (unavailable) { node.disabled=true; node.title='Indisponível no iOS Legacy'; }
            else if (action) { node.disabled=false; node.title=''; }
            if (/setZoom\((\d+(?:\.\d+)?)\)/.test(handler)) { var z=parseFloat(RegExp.$1); node.disabled=!cap.zoom || z>cap.zoomMax; }
            if (/adjustZoom/.test(handler)) node.disabled=!cap.zoom;
            if (node.tagName === 'A' && /gallery/.test(node.getAttribute('href') || '')) { node.removeAttribute('href'); node.textContent='Galeria indisponível'; }
        }
        panel(idx,root);
        document.getElementById('legacyDark_' + idx).disabled=!cap.darkScreen;
        if (!states[idx]) message(idx,'Consultando capacidades…');
    }
    function apply(idx,state) {
        states[idx]=state; var cap=state.capabilities || {};
        gate(idx,cap);
        options(document.getElementById('legacyResolution_' + idx),cap.resolutions || [],state.resolution);
        options(document.getElementById('legacyFPS_' + idx),cap.frameRates || [],Math.round(state.fps));
        document.getElementById('legacyDark_' + idx).textContent=state.darkScreen ? 'Acender tela' : 'Tela escura';
        if (full) {
            originalUpdate(idx,state);
            var labels={}; labels['ndiStateText_'+idx]='NDI indisponível'; labels['rtcStateText_'+idx]='MJPEG · WebRTC indisponível'; labels['webrtcBadge_'+idx]='MJPEG'; labels['gpuToggleBtn_'+idx]='GPU indisponível'; labels['ndiToggleBtn_'+idx]='NDI indisponível';
            for (var id in labels) { var label=document.getElementById(id); if(label) label.textContent=labels[id]; }
        } else {
            currentZoom=state.currentZoom;
            var torch=document.getElementById('btnTorch'); if(torch) torch.textContent=cap.torch ? (state.isTorchEnabled ? 'Flash: ON' : 'Flash: OFF') : 'Flash indisponível';
            var mic=document.getElementById('btnMicToggle'); if(mic) mic.textContent='Áudio indisponível';
        }
    }
    function poll(idx) {
        if(pending[idx]) return; pending[idx]=true;
        request(idx,'/state.json',function(data,status){ pending[idx]=false; if(status===200) apply(idx,data); else message(idx,data.error || 'Sem resposta'); });
    }
    function tap(event,idx) {
        if (!states[idx] || !states[idx].capabilities.focus) return;
        var img=document.getElementById(full ? 'videoImg_'+idx : 'streamImg'); if(!img) return;
        var rect=img.getBoundingClientRect(), width=img.naturalWidth, height=img.naturalHeight;
        if(!width || !height) return;
        var scale=Math.min(rect.width/width,rect.height/height), w=width*scale,h=height*scale;
        var x=(event.clientX-rect.left-(rect.width-w)/2)/w, y=(event.clientY-rect.top-(rect.height-h)/2)/h;
        if(x<0 || x>1 || y<0 || y>1) return;
        command(idx,'tap_focus',x.toFixed(4)+','+y.toFixed(4));
    }
    function gateGlobals() {
        var nodes=document.querySelectorAll('.studio-toolbar button,.studio-toolbar input,.studio-toolbar select,.fab-container button');
        for(var i=0;i<nodes.length;i++) {
            var handler=nodes[i].getAttribute('onclick') || '';
            if(!/toggleAutoAdaptSd/.test(handler)) { nodes[i].disabled=true; nodes[i].title='Indisponível no iOS Legacy'; }
        }
    }
    if(full) {
        var originalUpdate=updateCamUI;
        updateCamUI=apply;
        sendCmd=function(idx,path) { var action=decodeAction("'"+path+"'"); if(action) command(idx,action.type,action.value); };
        handleCamVideoTap=function(event,idx) { tap(event,idx); };
        // Keep all Android panels, but do not poll absent Android services.
        window.onload=function(){ renderCameras(); gateGlobals(); for(var i=0;i<cameras.length;i++){gate(i,{});poll(i);} setInterval(function(){for(var j=0;j<cameras.length;j++)poll(j);},1500); };
    } else {
        sendCommand=function(type,value) { command(0,type,value); };
        handleVideoTap=function(event) { tap(event,0); };
        updateState=function(){poll(0);};
        gate(0,{}); poll(0);
        stateTimer=setInterval(function(){poll(0);},2000);
    }
}());
