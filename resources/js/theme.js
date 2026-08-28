// Theme handling.  The initial theme comes from the URL (?theme=), then a
// saved preference, then the server-provided data-initial-theme, then
// system.  Changing the theme re-renders the nomnoml diagram so its
// colours follow light/dark (the diagram module is loaded later; the
// re-render only happens on user action, by which point it exists).
(function(){
var K='adacovex-theme',R=document.documentElement,S=document.getElementById('theme-select'),B=document.getElementById('save-theme');
var C=R.getAttribute('data-initial-theme')||'system';
function apply(t){if(t==='dark')R.setAttribute('data-theme','dark');else if(t==='light')R.setAttribute('data-theme','light');else R.removeAttribute('data-theme');}
function pick(){return S?S.value:'system';}
var use='system';var q=null;try{q=new URLSearchParams(location.search).get('theme');}catch(e){}
if(q==='light'||q==='dark'||q==='system'){use=q;}else if(C==='light'||C==='dark'){use=C;}else{var s=null;try{s=localStorage.getItem(K);}catch(e){}if(s==='light'||s==='dark'||s==='system'){use=s;}}
if(S)S.value=use;apply(use);
window.themeChanged=function(){apply(pick()); if(window.nomnomlViewActive && window.nomnomlViewActive() && window.renderNomnoml) renderNomnoml();};
window.saveTheme=function(){var t=pick();try{localStorage.setItem(K,t);}catch(e){}if(B){B.textContent='Saved';setTimeout(function(){B.textContent='Save settings';},1200);}};
})();
