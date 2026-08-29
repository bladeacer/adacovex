// Global search: dependency names through FlexSearch, page content through a
// section index.
//
// Both feeds stay behind one input.  FlexSearch (vendored) provides tolerant
// forward-token matching over dependency names / PURLs / scopes and seeds the
// dependency tree.  The section index is built from the rendered DOM at the
// granularity of a section -- a `.card` / `.chart-card`, a compliance-table
// row, a dependency node, or an HLR-tagged element -- plus one catch-all entry
// per tab.  Each section keeps its element, so selecting a content hit
// switches to the tab AND scrolls to (and briefly flashes) the exact section
// instead of only switching tabs.
//
// Content queries are tokenised (split on non-alphanumerics) and every token
// must appear in the section's lowercased text, so multi-word page text such
// as "orphan tags" or a section heading like "Proof Check Types" matches.
(function(){
var sections=[];                  // content sections: {tab,label,el,words,text}
var depResults=[];                // FlexSearch refs -> {name,scope,version}
var flexIdx=null;
(function initFlex(){
  try{
    var F=null;
    if(typeof FlexSearch!=='undefined'){
      if(FlexSearch.Index) F=FlexSearch.Index;
      else if(typeof FlexSearch==='function') F=FlexSearch;
    }
    if(!F) return;
    flexIdx=new F({tokenize:'forward'});
    if(typeof ADACOVEX_GRAPH!=='undefined' && ADACOVEX_GRAPH && ADACOVEX_GRAPH.dependencies){
      ADACOVEX_GRAPH.dependencies.forEach(function(dep,i){
        try{ flexIdx.add(i, dep.name+' '+(dep.version||'')+' '+(dep.scope||'')+' '+(dep.license||'')+' '+(dep.purl||'')); }catch(e){}
        depResults.push({name:dep.name,scope:dep.scope,version:dep.version,purl:dep.purl});
      });
    }
  }catch(e){ console.warn('FlexSearch init failed', e); }
})();
function tabOf(panel){ return panel&&panel.id ? panel.id.replace('tab-','') : ''; }
function wordsFor(s){
  return (s||'').toLowerCase().split(/[^a-z0-9]+/).filter(function(w){return w.length>1;}).join(' ');
}
function addSection(tab,label,el,text){
  var words=wordsFor(label+' '+(text||''));
  if(!words) return;
  sections.push({tab:tab,label:label,el:el||null,words:words,text:(text||'').substring(0,200)});
}
function buildSections(){
  if(sections.length) return;
  // Specific sections first (cards, rows, dep nodes) so a precise hit outranks
  // a whole tab; the per-tab catch-all entries are appended last and only act
  // as a fallback for a query that matches nothing more specific.
  document.querySelectorAll('.tab-panel .card, .tab-panel .chart-card').forEach(function(card){
    var panel=card.closest('.tab-panel');
    var h=card.querySelector('h1,h2,h3,h4');
    addSection(tabOf(panel), (h?h.textContent.trim():'')||'section', card, (h?h.textContent+' ':'')+card.innerText);
  });
  document.querySelectorAll('#tab-compliance table tr').forEach(function(tr){
    var panel=tr.closest('.tab-panel');
    var first=tr.querySelector('th,td:first-child');
    addSection(tabOf(panel), (first?first.textContent.trim():'')||'row', tr, tr.innerText);
  });
  document.querySelectorAll('[data-hlr]').forEach(function(el){
    var panel=el.closest('.tab-panel');
    var tag=el.getAttribute('data-hlr')||''; var pkg=el.getAttribute('data-pkg')||'';
    addSection(tabOf(panel), tag, el, tag+' '+pkg);
  });
  document.querySelectorAll('.dep-node').forEach(function(n){
    addSection('deps', n.getAttribute('data-name')||'', n, n.innerText);
  });
  var tabs=['overview','proof','tests','compliance','deps','charts','credits'];
  tabs.forEach(function(tab){
    var panel=document.getElementById('tab-'+tab);
    if(panel) addSection(tab, tab.charAt(0).toUpperCase()+tab.slice(1), panel, panel.innerText);
  });
}
buildSections();
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
  var q=gs.value.trim();
  if(sc) sc.classList.toggle('visible', q.length>0);
  sh.innerHTML='';
  if(!q){ sh.classList.remove('active'); return; }
  var results=[];
  var seen={};
  function push(tab,label,text,el,kind){
    var key=kind+':'+tab+':'+label;
    if(seen[key]) return; seen[key]=true;
    results.push({tab:tab,label:label,text:text,el:el||null,kind:kind||''});
  }
  // Dependency names via FlexSearch (tolerant prefix/token match).
  var ql=q.toLowerCase();
  try{
    if(flexIdx){
      var depCount=Math.min(5, depResults.length);
      var ids=flexIdx.search(ql, {limit:depCount}) || [];
      ids.forEach(function(id){
        var d=depResults[id];
        if(d) push('deps', d.name, '['+(d.scope||'')+'] '+d.name+' @ '+(d.version||''), null, 'dep');
      });
    }
  }catch(e){}
  // Page-content sections: every token must match (AND).  When FlexSearch
  // is unavailable, dependency names still resolve here via their .dep-node
  // and graph-metadata section entries.
  buildSections();
  var tokens=ql.split(/[^a-z0-9]+/).filter(function(w){return w.length>0;});
  if(tokens.length){
    sections.forEach(function(item){
      var ok=true;
      for(var t=0;t<tokens.length;t++){ if(item.words.indexOf(tokens[t])===-1){ ok=false; break; } }
      if(!ok) return;
      push(item.tab, item.label, item.text, item.el, 'content');
    });
  }
  buildSections();
  var tokens=ql.split(/[^a-z0-9]+/).filter(function(w){return w.length>0;});
  if(tokens.length){
    sections.forEach(function(item){
      var ok=true;
      for(var t=0;t<tokens.length;t++){ if(item.words.indexOf(tokens[t])===-1){ ok=false; break; } }
      if(!ok) return;
      push(item.tab, item.label, item.text, item.el, 'content');
    });
  }
  if(results.length===0){ sh.classList.remove('active'); return; }
  results.slice(0,15).forEach(function(r){
    var div=document.createElement('div');
    div.className='search-hit';
    var tabBadge=document.createElement('span');
    tabBadge.className='search-hit-tab';
    tabBadge.textContent=r.tab;
    div.appendChild(tabBadge);
    var label=document.createElement('div');
    label.textContent=r.label;
    div.appendChild(label);
    if(r.text){
      var snip=document.createElement('div');
      snip.className='search-hit-snippet';
      snip.textContent=r.text;
      div.appendChild(snip);
    }
    div.onclick=(function(hit){ return function(){ gotoHit(hit); }; })(r);
    sh.appendChild(div);
  });
  sh.classList.add('active');
}
function gotoHit(r){
  gs.value=r.label;
  sh.classList.remove('active');
  showTab(r.tab);
  if(r.el && r.el.scrollIntoView){
    requestAnimationFrame(function(){
      try{ r.el.scrollIntoView({behavior:'smooth',block:'start'}); }catch(e){ r.el.scrollIntoView(); }
      try{ r.el.classList.remove('search-flash'); void r.el.offsetWidth; r.el.classList.add('search-flash'); }catch(e){}
    });
  } else if(r.tab==='deps'){
    switchDepView('tree');
    var df=document.getElementById('dep-filter');
    if(df){ df.value=r.label; df.dispatchEvent(new Event('input')); }
  }
}
window.gotoSearchHit=gotoHit;
if(gs){
  gs.addEventListener('input', doSearch);
  gs.addEventListener('keydown', function(e){ if(e.key==='Escape'){ clearSearch(); } });
  gs.addEventListener('blur', function(){ setTimeout(function(){ sh.classList.remove('active'); }, 200); });
  gs.addEventListener('focus', function(){ if(gs.value.trim().length>0) doSearch(); });
}
})();