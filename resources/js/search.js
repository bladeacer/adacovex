// Global search.  Two indexes feed it: a full-text index of every tab's
// rendered content (lowercased, so page text such as "Orphan Tags" or an
// HLR tag matches a lowercase query) and a FlexSearch index of dependency
// names.  Clicking a hit switches to the tab that holds it.
(function(){
var fullTextIdx=[];
function buildFullTextIdx(){
  if(fullTextIdx.length>0) return;
  var tabs=['overview','proof','tests','compliance','deps','charts','credits'];
  tabs.forEach(function(tab){
    var panel=document.getElementById('tab-'+tab);
    if(!panel) return;
    var text=panel.innerText||'';
    var words=text.toLowerCase().split(/\s+/).filter(function(w){return w.length>2;});
    fullTextIdx.push({tab:tab,label:tab,words:words.join(' '),snippet:text.substring(0,200)});
  });
  // Index dep names separately for quick lookup
  if(typeof ADACOVEX_GRAPH!=='undefined' && ADACOVEX_GRAPH && ADACOVEX_GRAPH.dependencies){
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
    if(typeof ADACOVEX_GRAPH!=='undefined' && ADACOVEX_GRAPH && ADACOVEX_GRAPH.dependencies){
      ADACOVEX_GRAPH.dependencies.forEach(function(dep,i){ try{ flexIdx.add(i, dep.name+' '+dep.version+' '+dep.scope+' '+dep.license+' '+dep.purl); }catch(e){} });
    }
    document.querySelectorAll('.dep-node').forEach(function(n,i){
      var name=n.getAttribute('data-name')||'';
      try{ flexIdx.add(10000+i, name);}catch(e){}
    });
  }
}catch(e){ console.warn('FlexSearch init failed', e); }
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
        var dep = (typeof ADACOVEX_GRAPH!=='undefined' && ADACOVEX_GRAPH) ? ADACOVEX_GRAPH.dependencies[id] : null;
        if(dep){
          results.push({name:dep.name, scope:dep.scope, version:dep.version, tab:'deps', snippet:'['+dep.scope+'] '+dep.name+' @ '+dep.version});
        }
      });
    }
  }catch(e){}
  // Full-text search across all indexed content (queries and index are both
  // lowercased, so page text and HLR tags match).
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
})();
