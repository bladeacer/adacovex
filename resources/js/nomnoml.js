// Dependency diagram (nomnoml).  The graph renders as SVG (nomnoml's
// renderSvg), not a bitmap canvas: the SVG keeps every node as real
// geometry, so each box is clickable with its exact hitbox (no manual
// hit-testing and no zoom-math drift), the diagram scales with its viewBox
// (no upside-down or clipped text), and a wide graph scrolls horizontally
// inside the card.  Colours follow the active theme via CSS variables.
(function(){
function nomnomlViewActive(){
  var v=document.getElementById('dep-nomnoml-view');
  return !!(v && v.style.display !== 'none');
}
function renderNomnoml(){
  try{
    if(typeof nomnoml==='undefined' || typeof ADACOVEX_GRAPH==='undefined' || !ADACOVEX_GRAPH) return;
    var deps=ADACOVEX_GRAPH.dependencies||[];
    var showBase=document.getElementById('filter-base') ? document.getElementById('filter-base').checked : true;
    var showDev=document.getElementById('filter-dev') ? document.getElementById('filter-dev').checked : true;
    var showTrans=document.getElementById('filter-transitive') ? document.getElementById('filter-transitive').checked : true;
    var showVend=document.getElementById('filter-vendored') ? document.getElementById('filter-vendored').checked : true;
    var showSys=document.getElementById('filter-system') ? document.getElementById('filter-system').checked : true;
    var showTest=document.getElementById('filter-test') ? document.getElementById('filter-test').checked : true;
    function scopeOk(s){ if(s==='base') return showBase; if(s==='dev') return showDev; if(s==='transitive') return showTrans; if(s==='vendored') return showVend; if(s==='system') return showSys; if(s==='test') return showTest; return true; }
    var filtered=deps.filter(function(d){ return scopeOk(d.scope||'transitive'); });
    // Draw the diagram in the active theme: every nomnoml directive is
    // derived from the dashboard's CSS custom properties, so boxes, arrows,
    // canvas background and text follow light/dark (the theme select
    // re-renders via themeChanged()).  The note classifier gets the muted
    // table-head colour instead of nomnoml's default yellow.
    var cs=getComputedStyle(document.documentElement);
    var card=cs.getPropertyValue('--card').trim()||'#ffffff';
    var bg=cs.getPropertyValue('--bg').trim()||'#ffffff';
    var fg=cs.getPropertyValue('--fg').trim()||'#222222';
    var border=cs.getPropertyValue('--border').trim()||'#dddddd';
    var th=cs.getPropertyValue('--th').trim()||'#f0f0f0';
    var testCol=cs.getPropertyValue('--scope-test').trim()||'#00897b';
    var src='#fill: '+card+'\n#background: '+bg+'\n#stroke: '+fg+'\n#lineColor: '+border+'\n#fontColor: '+fg+'\n#fillArrows: false\n#direction: right\n#fontSize: 12\n#.note: fill='+th+'\n#.note: stroke='+border+'\n#.note: textColor='+fg+'\n';
    var root=deps[0]||{name:'root'};
    for(var i=0;i<deps.length;i++){
      if(deps[i].kind==='root' || deps[i].parent===0){ root=deps[i]; break; }
    }
    src += '['+(root.name||'root')+']\n';
    filtered.forEach(function(d){
      if(d.parent===0 || d.kind==='root') return;
      var parent = deps[d.parent-1] || deps[0];
      if(parent && !scopeOk(parent.scope||'transitive')) return;
      var pName = parent ? parent.name : 'root';
      src += '['+pName+']-->[ '+d.name+' ]\n';
    });
    var container=document.getElementById('nomnoml-canvas');
    if(!container) return;
    var svgStr='';
    try{ svgStr=nomnoml.renderSvg(src, document); }catch(e){ svgStr=''; }
    if(!svgStr) return;
    var doc=null;
    try{ doc=new DOMParser().parseFromString(svgStr, 'image/svg+xml'); }catch(e){ doc=null; }
    if(!doc || !doc.documentElement || doc.querySelector('parsererror')) return;
    var rootSvg=doc.documentElement;
    rootSvg.setAttribute('role','img');
    rootSvg.setAttribute('aria-label','Dependency hierarchy diagram');
    // Map every rendered node label to its graph index (1-based), then make
    // each node's box (the rect and its label text, both tagged with
    // data-name by nomnoml) clickable: clicking opens the same detail
    // panel as the tree view.  Exact SVG geometry = exact hitbox.
    var byName={};
    deps.forEach(function(d,k){ byName[String(d.name)]=k+1; });
    var tagged=rootSvg.querySelectorAll('[data-name]');
    var groups={};
    for(var j=0;j<tagged.length;j++){
      var nm=tagged[j].getAttribute('data-name');
      if(!nm) continue;
      (groups[nm]=groups[nm]||[]).push(tagged[j]);
    }
    Object.keys(groups).forEach(function(nm){
      var idx=byName[nm];
      if(!idx) return;
      var els=groups[nm];
      for(var g=0;g<els.length;g++){
        (function(one){
          one.addEventListener('click', function(ev){
            ev.stopPropagation();
            window.showDepDetails(idx);
          });
        })(els[g]);
      }
      // Hover tooltip with the dependency name (and version when known).
      var dep=deps[idx-1];
      var tip=(dep && dep.version) ? nm+' @ '+dep.version : nm;
      var t=doc.createElementNS('http://www.w3.org/2000/svg','title');
      t.textContent=tip;
      els[0].appendChild(t);
    });
    container.innerHTML='';
    container.appendChild(rootSvg);
  }catch(e){ console.warn('nomnoml render failed',e); }
}
window.nomnomlViewActive=nomnomlViewActive;
window.renderNomnoml=renderNomnoml;
window.downloadNomnoml=function(){
  var c=document.getElementById('nomnoml-canvas');
  if(!c) return;
  var svg=c.querySelector('svg');
  if(!svg) return;
  var str='<?xml version="1.0" encoding="UTF-8"?>\n'+svg.outerHTML;
  var a=document.createElement('a');
  a.href=URL.createObjectURL(new Blob([str], {type:'image/svg+xml'}));
  a.download='adacovex-deps.svg';
  a.click();
  setTimeout(function(){ URL.revokeObjectURL(a.href); }, 1000);
};
})();
