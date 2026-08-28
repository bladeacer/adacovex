// Dependency detail panel (shared by the tree view and the diagram view).
// Clicking a dependency name or a diagram node opens one split-view detail
// card: the view docks left, the detail docks right (full width until a
// dependency is selected).
(function(){
function esc(s){return String(s==null?'':s).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});}
window.esc=esc;
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
  var d=g ? g[idx-1] : null; if(!d) return;   var h='<strong>'+esc(d.name||'')+'</strong>';
   if(d.version) h+=' <span class="dep-badge">'+esc(d.version)+'</span>';   h+=' <span class="dep-badge scope-'+esc(d.scope||'')+'">'+esc(d.scope||'')+'</span>';   if(d.dev && d.scope!=='dev') h+=' <span class="dep-badge scope-dev">dev</span>';
  if(d.kind==='root') h+=' <span class="dep-badge">root</span>';
  h+=' <span class="dep-badge dep-details-close" onclick="closeDepDetails()">close &times;</span>';
   h+='<table class="dep-details-table">';
   h+='<tr><th>Name</th><td>'+esc(d.name||'')+'</td></tr>';
   h+='<tr><th>Version</th><td>'+esc(d.version||'')+'</td></tr>';
   h+='<tr><th>Scope</th><td class="lic">'+esc(d.scope||'')+'</td></tr>';
   h+='<tr><th>License</th><td class="lic">'+esc(d.license||'')+'</td></tr>';
   if(d.lang) h+='<tr><th>Language</th><td>'+esc(d.lang)+'</td></tr>';
   h+='<tr><th>PURL</th><td class="purl">'+esc(d.purl||'')+'</td></tr>';
   var par = (d.parent && g && g[d.parent-1]) ? g[d.parent-1].name : (d.parent===0 ? '(root)' : 'not available');
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
   h+='<tr><th>Link</th><td>'+(link ? '<a href="'+esc(link.href)+'" target="_blank" rel="noopener">'+esc(link.label)+' &#8599;</a>' : 'No link available')+'</td></tr>';
   h+='</table>';
    if(d.description) h+='<p class="dep-detail-note">'+esc(d.description)+'</p>';
    // System tools are discovered from the project's dev files + PATH: we
    // provision the resolved version but never a guessed external link or
    // licence, so say so instead of showing empty fields.
    if(d.scope==='system'){
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
};
})();
