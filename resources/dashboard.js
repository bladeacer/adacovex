
(function(){var K='adacovex-theme',R=document.documentElement,S=document.getElementById('theme-select'),B=document.getElementById('save-theme');var C=R.getAttribute('data-initial-theme')||'system';function apply(t){if(t==='dark')R.setAttribute('data-theme','dark');else if(t==='light')R.setAttribute('data-theme','light');else R.removeAttribute('data-theme');}function pick(){return S?S.value:'system';}var use='system';var q=null;try{q=new URLSearchParams(location.search).get('theme');}catch(e){}if(q==='light'||q==='dark'||q==='system'){use=q;}else if(C==='light'||C==='dark'){use=C;}else{var s=null;try{s=localStorage.getItem(K);}catch(e){}if(s==='light'||s==='dark'||s==='system'){use=s;}}if(S)S.value=use;apply(use);window.themeChanged=function(){apply(pick()); if(nomnomlViewActive()) renderNomnoml();};window.saveTheme=function(){var t=pick();try{localStorage.setItem(K,t);}catch(e){}if(B){B.textContent='Saved';setTimeout(function(){B.textContent='Save settings';},1200);}};window.showTab=function(id){var btns=document.querySelectorAll('.tab-btn'),panels=document.querySelectorAll('.tab-panel');btns.forEach(function(b){var a=b.getAttribute('data-tab')===id;b.classList.toggle('active',a);b.setAttribute('aria-selected',a?'true':'false');});panels.forEach(function(p){p.classList.toggle('active',p.id==='tab-'+id);});try{history.replaceState(null,'','#'+id);}catch(e){}try{localStorage.setItem('adacovex-tab',id);}catch(e){}};var init=null;try{init=location.hash.replace('#','');}catch(e){}if(!init)try{init=localStorage.getItem('adacovex-tab');}catch(e){}if(init && document.getElementById('tab-'+init))showTab(init);window.filterByScope=function(){
  var showBase=document.getElementById('filter-base') ? document.getElementById('filter-base').checked : true;
  var showDev=document.getElementById('filter-dev') ? document.getElementById('filter-dev').checked : true;
  var showTrans=document.getElementById('filter-transitive') ? document.getElementById('filter-transitive').checked : true;
  var showVend=document.getElementById('filter-vendored') ? document.getElementById('filter-vendored').checked : true;
  var q=(document.getElementById('dep-filter') ? document.getElementById('dep-filter').value.toLowerCase() : '');
  function scopeOk(s){ if(s==='base') return showBase; if(s==='dev') return showDev; if(s==='transitive') return showTrans; if(s==='vendored') return showVend; return true; }
  var nodes=Array.prototype.slice.call(document.querySelectorAll('.dep-node'));
  var info=new Map();
  nodes.forEach(function(n){
    var scope=n.getAttribute('data-scope')||'transitive';
    var name=(n.getAttribute('data-name')||'').toLowerCase();
    info.set(n, {scope:scope, match: name.indexOf(q)!==-1});
  });
  // hasMatch: the node itself or any descendant (scopes matter: a descendant
  // with a filtered-out scope does not keep the chain visible, but scope is
  // applied per node below, so a matching descendant only needs its OWN
  // scope to pass -- compute hasMatch on scope-filtered matches).
  nodes.slice().reverse().forEach(function(n){
    var m=info.get(n).match && scopeOk(info.get(n).scope);
    var kids=n.querySelectorAll(':scope > details > ul > .dep-node');
    kids.forEach(function(k){ var ik=info.get(k); if(ik && ik.hasMatch) m=true; });
    info.get(n).hasMatch=m;
  });
  var textFilter=q.length>0;
  // When the text filter starts, snapshot each details' open state so it can
  // be restored when the filter is cleared (forcing ancestors open while
  // filtering must not permanently collapse/expand the user's tree).
  if(!window.__depOpenSnap) window.__depOpenSnap=new Map();
  nodes.forEach(function(n){
    var d=n.querySelector(n.tagName==='DETAILS' ? ':scope' : ':scope > details');
    var open = d ? d.open : false;
    if(window.__depOpenSnap && !window.__depOpenSnap.has(n) && textFilter){
      window.__depOpenSnap.set(n, open);
    }
    if(!textFilter && window.__depOpenSnap && window.__depOpenSnap.has(n)){
      if(d) d.open=window.__depOpenSnap.get(n);
      window.__depOpenSnap.delete(n);
    }
  });
  nodes.forEach(function(n){
    var show=info.get(n).hasMatch && scopeOk(info.get(n).scope);
    // scope filtering hides a node and its subtree without touching open
    // state; the text filter auto-opens ancestors so matches stay reachable,
    // and the open state is restored once the filter is cleared.
    n.style.display= show ? '' : 'none';
    if(show && textFilter){
      var p=n.parentElement;
      while(p && p.classList && !p.classList.contains('dep-tree')){
        if(p.tagName==='DETAILS' && !p.open) p.open=true;
        p=p.parentElement;
      }
    }
  });
  if(document.getElementById('dep-nomnoml-view') && document.getElementById('dep-nomnoml-view').style.display !== 'none'){
    try{ renderNomnoml(); }catch(e){}
  }
};
var f=document.getElementById('dep-filter');if(f){f.addEventListener('input',function(){ window.filterByScope(); });}window.expandDeps=function(o){document.querySelectorAll('.dep-node details').forEach(function(d){d.open=o;});};
window.switchDepView=function(view){
  document.querySelectorAll('.dep-view-switch button').forEach(function(b){b.classList.toggle('active', b.getAttribute('data-view')===view);});
  document.getElementById('dep-tree-view').style.display = view==='tree' ? '' : 'none';
  document.getElementById('dep-nomnoml-view').style.display = view==='nomnoml' ? '' : 'none';
  if(view==='nomnoml') renderNomnoml();
  try{localStorage.setItem('adacovex-dep-view',view);}catch(e){}
};
window.downloadNomnoml=function(){
  var c=document.getElementById('nomnoml-canvas');
  if(!c) return;
  var a=document.createElement('a');
  a.href=c.toDataURL('image/png');
  a.download='adacovex-deps.png';
  a.click();
};
// Graph data injected by Ada
var ADACOVEX_GRAPH=__GRAPH_JSON__;
// Credits tab: the Playwright row is static in the template (it predates
// the resolved graph).  Fill its version cell from the graph when the
// target declares a playwright package (e.g. @playwright/test@1.62.1).
(function(){
  var cell=document.getElementById('credits-playwright');
  if(!cell) return;
  var g=(ADACOVEX_GRAPH && ADACOVEX_GRAPH.dependencies) ? ADACOVEX_GRAPH.dependencies : [];
  for(var i=0;i<g.length;i++){
    var d=g[i];
    if(d && d.version && (d.name||'').toLowerCase().indexOf('playwright')!==-1){
      cell.textContent=d.version+' / Apache-2.0';
      return;
    }
  }
})();
// Build full-text index from all tab content
var fullTextIdx=[];
function buildFullTextIdx(){
  if(fullTextIdx.length>0) return;
  var tabs=['overview','proof','tests','compliance','deps','charts'];
  tabs.forEach(function(tab){
    var panel=document.getElementById('tab-'+tab);
    if(!panel) return;
    var text=panel.innerText||'';
    var words=text.split(/\s+/).filter(function(w){return w.length>2;});
    fullTextIdx.push({tab:tab,label:tab,words:words.join(' '),snippet:text.substring(0,200)});
  });
  // Index dep names separately for quick lookup
  if(ADACOVEX_GRAPH && ADACOVEX_GRAPH.dependencies){
    ADACOVEX_GRAPH.dependencies.forEach(function(dep){
      var words=(dep.name||'')+' '+(dep.version||'')+' '+(dep.scope||'')+' '+(dep.license||'')+' '+(dep.purl||'');
      fullTextIdx.push({tab:'deps',label:dep.name,words:words.toLowerCase(),snippet:'['+dep.scope+'] '+dep.name+' @ '+dep.version});
    });
  }
  // Index HLR tags
  document.querySelectorAll('[data-hlr]').forEach(function(el){
    var tag=el.getAttribute('data-hlr');
    var pkg=el.getAttribute('data-pkg')||'';
    fullTextIdx.push({tab:'compliance',label:tag,words:(tag+' '+pkg).toLowerCase(),snippet:'HLR '+tag+' in '+pkg});
  });
}
buildFullTextIdx();
// FlexSearch index for dep names
var flexIdx=null;
try{
  var FlexIdxCtor = null;
  if(typeof FlexSearch!=='undefined'){
    if(FlexSearch.Index) FlexIdxCtor = FlexSearch.Index;
    else if(typeof FlexSearch==='function') FlexIdxCtor = FlexSearch;
  }
  if(FlexIdxCtor){
    flexIdx=new FlexIdxCtor({tokenize:'forward'});
    if(ADACOVEX_GRAPH && ADACOVEX_GRAPH.dependencies){
      ADACOVEX_GRAPH.dependencies.forEach(function(dep,i){ try{ flexIdx.add(i, dep.name+' '+dep.version+' '+dep.scope+' '+dep.license+' '+dep.purl); }catch(e){} });
    }
    document.querySelectorAll('.dep-node').forEach(function(n,i){
      var name=n.getAttribute('data-name')||'';
      try{ flexIdx.add(10000+i, name);}catch(e){}
    });
  }
}catch(e){ console.warn('FlexSearch init failed', e); }
function nomnomlViewActive(){
  var v=document.getElementById('dep-nomnoml-view');
  return !!(v && v.style.display !== 'none');
}
function renderNomnoml(){
  try{
    if(typeof nomnoml==='undefined' || !ADACOVEX_GRAPH) return;
    var deps=ADACOVEX_GRAPH.dependencies||[];
    var showBase=document.getElementById('filter-base') ? document.getElementById('filter-base').checked : true;
    var showDev=document.getElementById('filter-dev') ? document.getElementById('filter-dev').checked : true;
    var showTrans=document.getElementById('filter-transitive') ? document.getElementById('filter-transitive').checked : true;
    var showVend=document.getElementById('filter-vendored') ? document.getElementById('filter-vendored').checked : true;
    function scopeOk(s){ if(s==='base') return showBase; if(s==='dev') return showDev; if(s==='transitive') return showTrans; if(s==='vendored') return showVend; return true; }
    var filtered=deps.filter(function(d){ return scopeOk(d.scope||'transitive'); });
    var byScope={base:[],dev:[],transitive:[],vendored:[]};
    filtered.forEach(function(d){
      var scope=d.scope||'transitive';
      if(!byScope[scope]) byScope[scope]=[];
      byScope[scope].push(d);
    });
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
    var src='#fill: '+card+'\n#background: '+bg+'\n#stroke: '+fg+'\n#lineColor: '+border+'\n#fontColor: '+fg+'\n#fillArrows: false\n#.note: fill='+th+'\n#.note: stroke='+border+'\n#.note: textColor='+fg+'\n#direction: down\n';
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
    src += '\n';
    var canvas=document.getElementById('nomnoml-canvas');
    if(canvas){
      var out=null;
      try{ out=nomnoml.draw(canvas, src); }catch(e){ out=null; }
      // Record node rectangles (center x/y + w/h in layout space) so a click
      // on the canvas can be hit-tested back to a dependency and open its
      // detail panel -- the diagram is a single <canvas>, so boxes are not
      // DOM nodes and need manual hit-testing.
      window.__nomnomlHits=[];
      var zoom=(out && out.config && out.config.zoom) ? out.config.zoom : 1;
      if(out && out.layout && out.layout.nodes){
        out.layout.nodes.forEach(function(n){
          if(n && typeof n.x==='number' && n.id!==undefined){
            // Node x/y are centres in layout space; canvas pixels are
            // scaled by config.zoom, so store already-scaled rectangles.
            window.__nomnomlHits.push({name:String(n.id), x:n.x*zoom, y:n.y*zoom, w:(n.width||0)*zoom, h:(n.height||0)*zoom});
          }
        });
      }
      // One shared click handler transforms CSS coords to canvas pixels and
      // finds the enclosing box (nodes x/y are centres).
      if(!canvas.__nomnomlClickAttached){
        canvas.__nomnomlClickAttached=true;
        canvas.addEventListener('click', function(ev){
          var rect=canvas.getBoundingClientRect();
          if(rect.width===0 || rect.height===0) return;
          var cx=(ev.clientX-rect.left)*(canvas.width/rect.width);
          var cy=(ev.clientY-rect.top)*(canvas.height/rect.height);
          var hits=window.__nomnomlHits||[];
          // A little slack makes the tight text boxes easy to hit.  When
          // boxes overlap, pick the smallest enclosing one (the most specific
          // node) so clicks near a boundary open the right dependency.
          var pad=6, best=null, bestArea=Infinity;
          for(var i=0;i<hits.length;i++){
            var h=hits[i];
            if(cx>=h.x-h.w/2-pad && cx<=h.x+h.w/2+pad && cy>=h.y-h.h/2-pad && cy<=h.y+h.h/2+pad){
              var area=(h.w+2*pad)*(h.h+2*pad);
              if(area<bestArea){ bestArea=area; best=h; }
            }
          }
          if(best){
            var g=ADACOVEX_GRAPH.dependencies||[];
            for(var k=0;k<g.length;k++){
              if(String(g[k].name)===best.name){ window.showDepDetails(k+1); return; }
            }
          }
        });
      }
    }
  }catch(e){ console.warn('nomnoml render failed',e); }
}
var _origShowTab=window.showTab;
window.showTab=function(id){
  _origShowTab(id);
  if(id==='deps'){
    var v=null; try{v=localStorage.getItem('adacovex-dep-view');}catch(e){}
    if(v==='nomnoml') switchDepView('nomnoml');
  }
};
(function(){
  var v=null; try{v=localStorage.getItem('adacovex-dep-view');}catch(e){}
  if(v==='nomnoml') setTimeout(function(){switchDepView('nomnoml');}, 300);
})();
// Global search with full-text indexing
var gs=document.getElementById('global-search');
var sh=document.getElementById('search-hits');
var sc=document.getElementById('search-clear');
function clearSearch(){
  if(gs) gs.value='';
  if(sh) sh.classList.remove('active');
  if(sc) sc.classList.remove('visible');
  if(gs) gs.focus();
}
window.clearSearch=clearSearch;
function doSearch(){
  if(!gs || !sh) return;
  var q=gs.value.trim().toLowerCase();
  if(sc) sc.classList.toggle('visible', q.length>0);
  sh.innerHTML='';
  if(!q){ sh.classList.remove('active'); return; }
  var results=[];
  // Try FlexSearch first for dep names
  try{
    if(flexIdx){
      var ids=flexIdx.search(q, {limit:10});
      ids.forEach(function(id){
        var dep = ADACOVEX_GRAPH.dependencies[id];
        if(dep){
          results.push({name:dep.name, scope:dep.scope, version:dep.version, tab:'deps', snippet:'['+dep.scope+'] '+dep.name+' @ '+dep.version});
        }
      });
    }
  }catch(e){}
  // Full-text search across all indexed content
  var seen=new Set();
  fullTextIdx.forEach(function(item){
    if(item.words.indexOf(q)!==-1){
      var key=item.tab+':'+item.label;
      if(!seen.has(key)){
        seen.add(key);
        if(results.length<15){
          results.push({name:item.label, scope:item.tab, version:'', tab:item.tab, snippet:item.snippet});
        }
      }
    }
  });
  // Fallback: filter dep nodes
  if(results.length===0){
    document.querySelectorAll('.dep-node').forEach(function(n){
      var name=(n.getAttribute('data-name')||'').toLowerCase();
      if(name.indexOf(q)!==-1){
        var scope=n.getAttribute('data-scope')||'';
        results.push({name:name, scope:scope, version:'', tab:'deps', snippet:'['+scope+'] '+name});
      }
    });
    results=results.slice(0,15);
  }
  if(results.length===0){ sh.classList.remove('active'); return; }
  results.forEach(function(r){
    var div=document.createElement('div');
    div.className='search-hit';
    var label=document.createElement('div');
    label.textContent=r.name;
    div.appendChild(label);
    if(r.snippet){
      var snip=document.createElement('div');
      snip.className='search-hit-snippet';
      snip.textContent=r.snippet;
      div.appendChild(snip);
    }
    var tabBadge=document.createElement('span');
    tabBadge.className='search-hit-tab';
    tabBadge.textContent=r.tab;
    div.insertBefore(tabBadge, div.firstChild);
    div.onclick=function(){ gs.value=r.name; sh.classList.remove('active'); showTab(r.tab); if(r.tab==='deps'){ switchDepView('tree'); var df=document.getElementById('dep-filter'); if(df){df.value=r.name; df.dispatchEvent(new Event('input'));}}};
    sh.appendChild(div);
  });
  sh.classList.add('active');
}
if(gs){
  gs.addEventListener('input', doSearch);
  gs.addEventListener('keydown', function(e){
    if(e.key==='Escape'){ clearSearch(); }
  });
  gs.addEventListener('blur', function(){ setTimeout(function(){ sh.classList.remove('active'); }, 200); });
  gs.addEventListener('focus', function(){ if(gs.value.trim().length>0) doSearch(); });
}
window.filterDeps=function(){var e=document.getElementById('dep-filter');if(e)e.dispatchEvent(new Event('input'));};
// --- Dependency details popup (click a dep name) ---
function esc(s){return String(s==null?'':s).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});}
function purlInfo(purl){
  var p=purl||''; var m=null;
  // Strip a trailing @version (npm scoped names keep their leading @).
  function stripVer(s){ return s.replace(/@[^@]*$/,''); }
  m=p.match(/^pkg:github\/([^\/@]+)\/([^\/@]+)/); if(m) return {label:'GitHub', href:'https://github.com/'+m[1]+'/'+stripVer(m[2])};
  m=p.match(/^pkg:gitlab\/([^\/@]+)\/([^\/@]+)/); if(m) return {label:'GitLab', href:'https://gitlab.com/'+m[1]+'/'+stripVer(m[2])};
  m=p.match(/^pkg:bitbucket\/([^\/@]+)\/([^\/@]+)/); if(m) return {label:'Bitbucket', href:'https://bitbucket.org/'+m[1]+'/'+stripVer(m[2])};
  m=p.match(/^pkg:npm\/(@[^\/]+\/[^@]+|[^@]+)/); if(m) return {label:'npm', href:'https://www.npmjs.com/package/'+stripVer(m[1])};
  m=p.match(/^pkg:cargo\/([^@]+)/); if(m) return {label:'crates.io', href:'https://crates.io/crates/'+stripVer(m[1])};
  m=p.match(/^pkg:pypi\/([^@]+)/); if(m) return {label:'PyPI', href:'https://pypi.org/project/'+stripVer(m[1])};
  m=p.match(/^pkg:golang\/([^@]+)/); if(m) return {label:'pkg.go.dev', href:'https://pkg.go.dev/'+stripVer(m[1])};
  m=p.match(/^pkg:alire\/([^@]+)/); if(m) return {label:'Alire', href:'https://alire.ada.dev/crates/'+stripVer(m[1])};
  // Unknown ecosystem: there is no reliable direct registry/repo link, so
  // no link is offered (a GitHub search URL is noise for generic/system
  // dependencies).
  return null;
}
window.showDepDetails=function(idx){
  var pop=document.getElementById('dep-detail-popup'); if(!pop) return;
  var g=(typeof ADACOVEX_GRAPH!=='undefined' && ADACOVEX_GRAPH && ADACOVEX_GRAPH.dependencies) ? ADACOVEX_GRAPH.dependencies : null;
  var d=g ? g[idx-1] : null; if(!d) return;
  var h='<strong>'+ (d.name||'') +'</strong>';
  if(d.version) h+=' <span class="dep-badge">'+esc(d.version)+'</span>';
  h+=' <span class="dep-badge '+esc(d.scope||'')+'">'+esc(d.scope||'')+'</span>';
  if(d.purl && String(d.purl).indexOf('pkg:generic/')===0) h+=' <span class="dep-badge scope-system">system</span>';
  if(d.kind==='root') h+=' <span class="dep-badge">root</span>';
  h+=' <span class="dep-badge dep-details-close" onclick="closeDepDetails()">close &times;</span>';
   h+='<table class="dep-details-table">';
   h+='<tr><th>Name</th><td>'+esc(d.name||'')+'</td></tr>';
   h+='<tr><th>Version</th><td>'+esc(d.version||'')+'</td></tr>';
   h+='<tr><th>Scope</th><td class="lic">'+esc(d.scope||'')+'</td></tr>';
   h+='<tr><th>License</th><td class="lic">'+esc(d.license||'')+'</td></tr>';
   if(d.lang) h+='<tr><th>Language</th><td>'+esc(d.lang)+'</td></tr>';
   h+='<tr><th>PURL</th><td class="purl">'+esc(d.purl||'')+'</td></tr>';
   var par = (d.parent && g && g[d.parent-1]) ? g[d.parent-1].name : (d.parent===0 ? '(root)' : '\u2014');
   h+='<tr><th>Parent</th><td>'+esc(par)+'</td></tr>';
   // Preferred link: the resolved source repository / project website (from
   // alr show / the lockfile), which never produces a guessed or dead link.
   // Fall back to the PURL-derived registry link only when that resolves to a
   // real, known registry (never a GitHub search page).
   var link=null;
   if(d.website && /^https?:\/\//i.test(String(d.website))){
     link={label:'Source', href:d.website};
   } else {
     link=purlInfo(d.purl);
   }
   h+='<tr><th>Link</th><td>'+(link ? '<a href="'+esc(link.href)+'" target="_blank" rel="noopener">'+esc(link.label)+' &#8599;</a>' : '\u2014')+'</td></tr>';
   h+='</table>';
   if(d.description) h+='<p class="dep-detail-note">'+esc(d.description)+'</p>';
   // System tools (pkg:generic/*) are discovered from the project's dev
   // files + PATH: we provision the resolved version but never a guessed
   // external link or licence, so say so instead of showing empty fields.
   if(d.purl && String(d.purl).indexOf('pkg:generic/')===0){
     h+='<p class="dep-system-note">System tool. Version is resolved from the installed binary on PATH. No external link or licence is provisioned.</p>';
   }
  pop.innerHTML=h;
  pop.hidden=false;
  // Activate the split layout: tree/diagram docks left, details right.
  // By default (no selection) the view fills the screen; the split appears
  // only once a dependency is selected, so the tree or diagram keeps its
  // full width until then.
  var shell=document.getElementById('dep-split'); if(shell) shell.classList.add('dep-split-active');
  pop.scrollIntoView({block:'nearest'});
};
window.closeDepDetails=function(){
  var pop=document.getElementById('dep-detail-popup'); if(pop) pop.hidden=true;
  var shell=document.getElementById('dep-split'); if(shell) shell.classList.remove('dep-split-active');
};})();