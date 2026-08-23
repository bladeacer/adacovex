
(function(){var K='adacovex-theme',R=document.documentElement,S=document.getElementById('theme-select'),B=document.getElementById('save-theme');var C=R.getAttribute('data-initial-theme')||'system';function apply(t){if(t==='dark')R.setAttribute('data-theme','dark');else if(t==='light')R.setAttribute('data-theme','light');else R.removeAttribute('data-theme');}function pick(){return S?S.value:'system';}var use='system';var q=null;try{q=new URLSearchParams(location.search).get('theme');}catch(e){}if(q==='light'||q==='dark'||q==='system'){use=q;}else if(C==='light'||C==='dark'){use=C;}else{var s=null;try{s=localStorage.getItem(K);}catch(e){}if(s==='light'||s==='dark'||s==='system'){use=s;}}if(S)S.value=use;apply(use);window.themeChanged=function(){apply(pick());};window.saveTheme=function(){var t=pick();try{localStorage.setItem(K,t);}catch(e){}if(B){B.textContent='Saved';setTimeout(function(){B.textContent='Save settings';},1200);}};window.showTab=function(id){var btns=document.querySelectorAll('.tab-btn'),panels=document.querySelectorAll('.tab-panel');btns.forEach(function(b){var a=b.getAttribute('data-tab')===id;b.classList.toggle('active',a);b.setAttribute('aria-selected',a?'true':'false');});panels.forEach(function(p){p.classList.toggle('active',p.id==='tab-'+id);});try{history.replaceState(null,'','#'+id);}catch(e){}try{localStorage.setItem('adacovex-tab',id);}catch(e){}};var init=null;try{init=location.hash.replace('#','');}catch(e){}if(!init)try{init=localStorage.getItem('adacovex-tab');}catch(e){}if(init && document.getElementById('tab-'+init))showTab(init);window.filterByScope=function(){
  var showBase=document.getElementById('filter-base') ? document.getElementById('filter-base').checked : true;
  var showDev=document.getElementById('filter-dev') ? document.getElementById('filter-dev').checked : true;
  var showTrans=document.getElementById('filter-transitive') ? document.getElementById('filter-transitive').checked : true;
  var showVend=document.getElementById('filter-vendored') ? document.getElementById('filter-vendored').checked : true;
  var q=(document.getElementById('dep-filter') ? document.getElementById('dep-filter').value.toLowerCase() : '');
  document.querySelectorAll('.dep-node').forEach(function(n){
    var scope=n.getAttribute('data-scope')||'transitive';
    var name=(n.getAttribute('data-name')||'').toLowerCase();
    var ok=true;
    if(scope==='base' && !showBase) ok=false;
    else if(scope==='dev' && !showDev) ok=false;
    else if(scope==='transitive' && !showTrans) ok=false;
    else if(scope==='vendored' && !showVend) ok=false;
    if(q && name.indexOf(q)===-1) ok=false;
    n.style.display= ok ? '' : 'none';
  });
  // Re-render diagram if visible
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
// FlexSearch index built from graph + packages
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
      ADACOVEX_GRAPH.dependencies.forEach(function(dep,i){ try{ flexIdx.add(i, dep.name+' '+dep.version+' '+dep.scope); }catch(e){} });
    }
    document.querySelectorAll('.dep-node').forEach(function(n,i){
      var name=n.getAttribute('data-name')||'';
      try{ flexIdx.add(10000+i, name);}catch(e){}
    });
  }
}catch(e){ console.warn('FlexSearch init failed', e); }
function renderNomnoml(){
  try{
    if(typeof nomnoml==='undefined' || !ADACOVEX_GRAPH) return;
    var deps=ADACOVEX_GRAPH.dependencies||[];
    // Respect scope filters (same checkboxes as tree view)
    var showBase=document.getElementById('filter-base') ? document.getElementById('filter-base').checked : true;
    var showDev=document.getElementById('filter-dev') ? document.getElementById('filter-dev').checked : true;
    var showTrans=document.getElementById('filter-transitive') ? document.getElementById('filter-transitive').checked : true;
    var showVend=document.getElementById('filter-vendored') ? document.getElementById('filter-vendored').checked : true;
    function scopeOk(s){ if(s==='base') return showBase; if(s==='dev') return showDev; if(s==='transitive') return showTrans; if(s==='vendored') return showVend; return true; }
    var filtered=deps.filter(function(d){ return scopeOk(d.scope||'transitive'); });
    var lines=['#direction: down','#[<hidden> root]'];
    var byScope={base:[],dev:[],transitive:[],vendored:[]};
    filtered.forEach(function(d){
      var scope=d.scope||'transitive';
      if(!byScope[scope]) byScope[scope]=[];
      byScope[scope].push(d);
    });
    // Build nomnoml source: edges parent->child, skipping hidden parents/children
    var cardBg=getComputedStyle(document.documentElement).getPropertyValue('--card').trim()||'#fff';var fg=getComputedStyle(document.documentElement).getPropertyValue('--fg').trim()||'#333';var src='#.box: fill='+cardBg+'\n#.arrow: fill='+fg+'\n#direction: down\n';
    src += '[<box> adacovex]\n';
    filtered.forEach(function(d){
      if(d.parent===0 || d.kind==='root') return;
      var parent = deps[d.parent-1] || deps[0];
      if(parent && !scopeOk(parent.scope||'transitive')) return;
      var pName = parent ? parent.name : 'root';
      src += '['+pName+']-->[ '+d.name+' ]\n';
    });
    // Add legend
    src += '\n[<note> Legend: base=alire.toml, dev=alire-dev.toml, vendored=.adacovex/patches]\n';
    var canvas=document.getElementById('nomnoml-canvas');
    if(canvas) nomnoml.draw(canvas, src);
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
// Global search with FlexSearch
var gs=document.getElementById('global-search');
var sh=document.getElementById('search-hits');
if(gs && sh){
  gs.addEventListener('input', function(){
    var q=gs.value.trim().toLowerCase();
    sh.innerHTML='';
    if(!q){ sh.classList.remove('active'); return; }
    var results=[];
    // Try FlexSearch first
    try{
      if(flexIdx){
        var ids=flexIdx.search(q, {limit:20});
        ids.forEach(function(id){
          var dep = ADACOVEX_GRAPH.dependencies[id];
          if(dep) results.push(dep.name+' ('+dep.scope+')');
        });
      }
    }catch(e){}
    // Fallback: filter dep nodes
    if(results.length===0){
      document.querySelectorAll('.dep-node').forEach(function(n){
        var name=(n.getAttribute('data-name')||'').toLowerCase();
        if(name.indexOf(q)!==-1) results.push(name);
      });
      results=results.slice(0,20);
    }
    if(results.length===0){ sh.classList.remove('active'); return; }
    results.forEach(function(r){
      var div=document.createElement('div');
      div.className='search-hit';
      div.textContent=r;
      div.onclick=function(){ gs.value=r; sh.classList.remove('active'); switchDepView('tree'); document.getElementById('dep-filter').value=r; document.getElementById('dep-filter').dispatchEvent(new Event('input')); showTab('deps'); };
      sh.appendChild(div);
    });
    sh.classList.add('active');
  });
  gs.addEventListener('blur', function(){ setTimeout(function(){ sh.classList.remove('active'); }, 200); });
}
window.filterDeps=function(){var e=document.getElementById('dep-filter');if(e)e.dispatchEvent(new Event('input'));};
// --- Dependency details popup (click a dep name) ---
function esc(s){return String(s==null?'':s).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});}
function purlInfo(purl){
  var p=purl||''; var m=null;
  // pkg:github/owner/name[@v]
  m=p.match(/^pkg:github\/([^\/@]+)\/([^\/@]+)/); if(m) return {label:'GitHub', href:'https://github.com/'+m[1]+'/'+m[2].replace(/@.*$/,'')};
  m=p.match(/^pkg:npm\/([^@]+)/); if(m) return {label:'npm', href:'https://www.npmjs.com/package/'+m[1]};
  m=p.match(/^pkg:cargo\/([^@]+)/); if(m) return {label:'crates.io', href:'https://crates.io/crates/'+m[1]};
  m=p.match(/^pkg:pypi\/([^@]+)/); if(m) return {label:'PyPI', href:'https://pypi.org/project/'+m[1]};
  m=p.match(/^pkg:golang\/([^@]+)/); if(m) return {label:'pkg.go.dev', href:'https://pkg.go.dev/'+m[1]};
  m=p.match(/^pkg:alire\/([^@]+)/); if(m) return {label:'Alire', href:'https://alire.ada.dev/crates/'+m[1]};
  if(p) return {label:'GitHub search', href:'https://github.com/search?q='+encodeURIComponent(p)+'&type=repositories'};
  return null;
}
window.showDepDetails=function(idx){
  var pop=document.getElementById('dep-detail-popup'); if(!pop) return;
  var g=(typeof ADACOVEX_GRAPH!=='undefined' && ADACOVEX_GRAPH && ADACOVEX_GRAPH.dependencies) ? ADACOVEX_GRAPH.dependencies : null;
  var d=g ? g[idx-1] : null; if(!d) return;
  var h='<strong>'+ (d.name||'') +'</strong>';
  if(d.version) h+=' <span class="dep-badge">'+esc(d.version)+'</span>';
  h+=' <span class="dep-badge '+esc(d.scope||'')+'">'+esc(d.scope||'')+'</span>';
  if(d.kind==='root') h+=' <span class="dep-badge">root</span>';
  h+=' <span class="dep-badge dep-details-close" onclick="closeDepDetails()">close &times;</span>';
  h+='<table class="dep-details-table">';
  h+='<tr><th>Name</th><td>'+esc(d.name||'')+'</td></tr>';
  h+='<tr><th>Version</th><td>'+esc(d.version||'')+'</td></tr>';
  h+='<tr><th>Scope</th><td class="lic">'+esc(d.scope||'')+'</td></tr>';
  h+='<tr><th>License</th><td class="lic">'+esc(d.license||'')+'</td></tr>';
  h+='<tr><th>PURL</th><td class="purl">'+esc(d.purl||'')+'</td></tr>';
  var par = (d.parent && g && g[d.parent-1]) ? g[d.parent-1].name : (d.parent===0 ? '(root)' : '\u2014');
  h+='<tr><th>Parent</th><td>'+esc(par)+'</td></tr>';
  var info=purlInfo(d.purl);
  h+='<tr><th>Link</th><td>'+(info ? '<a href="'+info.href+'" target="_blank" rel="noopener">'+info.label+' &#8599;</a>' : '\u2014')+'</td></tr>';
  h+='</table>';
  pop.innerHTML=h;
  pop.hidden=false; pop.scrollIntoView({block:'nearest'});
};
window.closeDepDetails=function(){var pop=document.getElementById('dep-detail-popup'); if(pop) pop.hidden=true;};})();
