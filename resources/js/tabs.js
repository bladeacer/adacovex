// Tab switching.  The active tab persists in the URL hash and in
// localStorage so a reload (or a shared link) lands on the same section.
(function(){
window.showTab=function(id){
  var btns=document.querySelectorAll('.tab-btn'),panels=document.querySelectorAll('.tab-panel');
  btns.forEach(function(b){var a=b.getAttribute('data-tab')===id;b.classList.toggle('active',a);b.setAttribute('aria-selected',a?'true':'false');});
  panels.forEach(function(p){p.classList.toggle('active',p.id==='tab-'+id);});
  try{history.replaceState(null,'','#'+id);}catch(e){}
  try{localStorage.setItem('adacovex-tab',id);}catch(e){}
};
var init=null;try{init=location.hash.replace('#','');}catch(e){}
if(!init)try{init=localStorage.getItem('adacovex-tab');}catch(e){}
if(init && document.getElementById('tab-'+init))showTab(init);
})();
