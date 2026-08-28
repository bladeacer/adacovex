// Dependency tree view.  Holds the injected graph data (used by every
// other module), the scope + name filter, expand/collapse, and the
// tree/diagram view switch.  The view preference persists; entering the
// deps tab restores it.
var ADACOVEX_GRAPH=__GRAPH_JSON__;
(function(){
window.filterByScope=function(){
  var showBase=document.getElementById('filter-base') ? document.getElementById('filter-base').checked : true;
  var showDev=document.getElementById('filter-dev') ? document.getElementById('filter-dev').checked : true;
  var showTrans=document.getElementById('filter-transitive') ? document.getElementById('filter-transitive').checked : true;
  var showVend=document.getElementById('filter-vendored') ? document.getElementById('filter-vendored').checked : true;
  var showSys=document.getElementById('filter-system') ? document.getElementById('filter-system').checked : true;
  var showTest=document.getElementById('filter-test') ? document.getElementById('filter-test').checked : true;
  var q=(document.getElementById('dep-filter') ? document.getElementById('dep-filter').value.toLowerCase() : '');
  function scopeOk(s){ if(s==='base') return showBase; if(s==='dev') return showDev; if(s==='transitive') return showTrans; if(s==='vendored') return showVend; if(s==='system') return showSys; if(s==='test') return showTest; return true; }
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
var f=document.getElementById('dep-filter');if(f){f.addEventListener('input',function(){ window.filterByScope(); });}
window.expandDeps=function(o){document.querySelectorAll('.dep-node details').forEach(function(d){d.open=o;});};
window.switchDepView=function(view){
  document.querySelectorAll('.dep-view-switch button').forEach(function(b){b.classList.toggle('active', b.getAttribute('data-view')===view);});
  document.getElementById('dep-tree-view').style.display = view==='tree' ? '' : 'none';
  document.getElementById('dep-nomnoml-view').style.display = view==='nomnoml' ? '' : 'none';
  if(view==='nomnoml') renderNomnoml();
  try{localStorage.setItem('adacovex-dep-view',view);}catch(e){}
};
window.filterDeps=function(){var e=document.getElementById('dep-filter');if(e)e.dispatchEvent(new Event('input'));};
// Entering the deps tab restores the saved view (tree or diagram).
var _origShowTab=window.showTab;
window.showTab=function(id){
  _origShowTab(id);
  if(id==='deps'){
    var v=null; try{v=localStorage.getItem('adacovex-dep-view');}catch(e){}
    if(v==='nomnoml') switchDepView('nomnoml');
  }
};
var v=null; try{v=localStorage.getItem('adacovex-dep-view');}catch(e){}
if(v==='nomnoml') setTimeout(function(){switchDepView('nomnoml');}, 300);
})();
