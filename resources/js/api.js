// REST API playground.
//
// Turns the dashboard into an interactive API explorer.  Every endpoint the
// --serve server dispatches on is listed as a clickable, searchable button
// grouped by purpose.  Clicking an endpoint fetches it in the browser and
// previews the response:
//   - JSON endpoints are pretty-printed and syntax-highlighted with the
//     vendored yace tokenizer (window.YaceTok), with object keys coloured
//     separately from string values;
//   - SVG badge endpoints show the live image plus the raw markup;
//   - the /docs endpoint shows its plain-text response.
// A toolbar offers Copy and Download for the raw response body, so the
// playground doubles as a lightweight HTTP client for the JSON API.
//
// The endpoint list is static (the surface is fixed), but each request is
// made live against the serving origin, so what you preview is exactly what
// curl + jq would receive.
(function(){
"use strict";

var PANEL = document.getElementById('tab-api');
if (!PANEL) return;

var GROUPS = [
  { title: 'Metrics', endpoints: [
    { m:'GET', path:'/api/metrics', kind:'json', desc:'Key assessment metrics: SPARK level, VCs proved, tests passed/failed, docstring coverage, and per-standard compliance status.' }
  ]},
  { title: 'Dependencies', endpoints: [
    { m:'GET', path:'/api/deps', kind:'json', desc:'Resolved dependency graph as JSON (name, version, scope, parent, licence, PURL) -- the same data the SBOM embeds.' }
  ]},
  { title: 'Badges', endpoints: [
    { m:'GET', path:'/badge/spark.svg', kind:'svg', desc:'SPARK assurance-level badge (Stone..Platinum).' },
    { m:'GET', path:'/badge/tests.svg', kind:'svg', desc:'Test pass/fail badge.' },
    { m:'GET', path:'/badge/do178c.svg', kind:'svg', desc:'DO-178C compliance badge (Achieved / Unmet).' },
    { m:'GET', path:'/badge/iso26262.svg', kind:'svg', desc:'ISO 26262 compliance badge.' },
    { m:'GET', path:'/badge/iec62304.svg', kind:'svg', desc:'IEC 62304 compliance badge.' }
  ]},
  { title: 'Documentation', endpoints: [
    { m:'GET', path:'/docs', kind:'text', desc:'Plain-text pointer to the repository documentation under docs/.' }
  ]}
];

var keyRule = { type:'prop', pattern: /"(\\.|[^"\\])*"(?=\s*:)/ };
var HL = (window.YaceTok && window.YaceTok.code) ? window.YaceTok.code([keyRule]) : null;

function prettyJson(s){
  try { return JSON.stringify(JSON.parse(s), null, 2); }
  catch (e) { return s; }
}

function el(tag, cls, text){
  var n = document.createElement(tag);
  if (cls) n.className = cls;
  if (text != null) n.textContent = text;
  return n;
}

// Full playground shell.
PANEL.innerHTML = '';
var card = el('div', 'card api-card');
PANEL.appendChild(card);

var intro = el('p', 'api-intro',
  'Explore the built-in JSON API, dependency graph, SVG badges and docs ' +
  'endpoint served by this adacovex instance. Click an endpoint (or type to ' +
  'filter), then preview the live response. JSON is pretty-printed and ' +
  'syntax-highlighted with the vendored yace tokenizer.');
card.appendChild(intro);

var searchRow = el('div', 'api-search-row');
var search = el('input', 'api-search');
search.type = 'search';
search.placeholder = 'Filter endpoints (e.g. metrics, badge, deps)';
search.setAttribute('aria-label', 'Filter API endpoints');
searchRow.appendChild(search);
card.appendChild(searchRow);

var groupsWrap = el('div', 'api-groups');
card.appendChild(groupsWrap);

var result = el('div', 'api-result');
result.hidden = true;
card.appendChild(result);

// One .api-group per category; each endpoint is a .api-btn button.
var groupNodes = GROUPS.map(function(g){
  var gw = el('div', 'api-group');
  var title = el('h3', 'api-group-title', g.title);
  gw.appendChild(title);
  var list = el('div', 'api-endpoints');
  g.endpoints.forEach(function(e){
    var b = el('button', 'api-btn');
    b.type = 'button';
    var method = el('span', 'api-method', e.m);
    var path = el('span', 'api-path', e.path);
    var d = el('span', 'api-desc', e.desc);
    b.appendChild(method);
    b.appendChild(path);
    b.appendChild(d);
    b.addEventListener('click', function(){ run(e, b); });
    list.appendChild(b);
  });
  gw.appendChild(list);
  groupsWrap.appendChild(gw);
  return { el: gw, titleText: g.title, titleNode: title, list: list,
           endpoints: g.endpoints, btns: list.querySelectorAll('.api-btn') };
});

function filterGroups(q){
  q = q.trim().toLowerCase();
  var any = false;
  groupNodes.forEach(function(gn){
    var showGroup = false;
    var btns = gn.btns;
    var i = 0;
    gn.endpoints.forEach(function(e, idx){
      var hit = !q || (e.path + ' ' + e.desc + ' ' + gn.titleText).toLowerCase().indexOf(q) !== -1;
      btns[idx].style.display = hit ? '' : 'none';
      if (hit) showGroup = true;
    });
    gn.el.style.display = showGroup ? '' : 'none';
    if (showGroup) any = true;
  });
  var empty = document.getElementById('api-empty') || el('p', 'api-empty', 'No endpoints match your filter.');
  empty.id = 'api-empty';
  empty.style.display = any ? 'none' : '';
  if (!any) groupsWrap.appendChild(empty);
  else if (empty.parentNode === groupsWrap) groupsWrap.removeChild(empty);
}
search.addEventListener('input', function(){ filterGroups(search.value); });
search.addEventListener('keydown', function(e){ if (e.key === 'Escape') { search.value=''; filterGroups(''); } });

function run(e, pressedBtn){
  groupNodes.forEach(function(gn){
    for (var i=0;i<gn.btns.length;i++){ gn.btns[i].classList.remove('active'); }
  });
  pressedBtn.classList.add('active');
  result.hidden = false;
  result.innerHTML = '';

  var head = el('div', 'api-result-head');
  var reqLine = el('span', 'api-reqline', e.m + ' ' + e.path);
  var status = el('span', 'api-status', 'loading...');
  status.id = 'api-status';
  head.appendChild(reqLine);
  head.appendChild(status);
  var toolbar = el('div', 'api-toolbar');
  var copyBtn = el('button', 'theme-toggle api-copy', 'Copy');
  copyBtn.type = 'button';
  var dlBtn = el('button', 'theme-toggle api-download', 'Download');
  dlBtn.type = 'button';
  toolbar.appendChild(copyBtn);
  toolbar.appendChild(dlBtn);
  head.appendChild(toolbar);
  result.appendChild(head);

  var body = el('div', 'api-body');
  body.id = 'api-body';
  result.appendChild(body);

  fetch(e.path, { headers: { Accept: e.kind === 'json' ? 'application/json' : '*/*' } })
    .then(function(resp){
      var st = document.getElementById('api-status');
      if (st) st.textContent = resp.status + ' ' + resp.statusText;
      return resp.text();
    })
    .then(function(text){
      renderBody(e, text);
    })
    .catch(function(err){
      var st = document.getElementById('api-status');
      if (st) st.textContent = 'error';
      renderBody(e, 'Request failed: ' + err);
    });

  function renderBody(req, text){
    var b = document.getElementById('api-body');
    if (!b) return;
    b.innerHTML = '';
    var pre = el('pre', 'api-pre');
    pre.setAttribute('tabindex','0');
    if (req.kind === 'json') {
      var pretty = prettyJson(text);
      if (HL) pre.innerHTML = HL(pretty);
      else pre.textContent = pretty;
    } else if (req.kind === 'svg') {
      var img = el('div', 'api-svg-preview');
      img.innerHTML = '<img src="' + req.path + '" alt="' + req.path + '">';
      b.appendChild(img);
      if (HL) pre.innerHTML = HL(text);
      else pre.textContent = text;
    } else {
      pre.textContent = text;
    }
    b.appendChild(pre);

    copyBtn.onclick = function(){
      copyText(text).then(function(){ copyBtn.textContent='Copied'; setTimeout(function(){ copyBtn.textContent='Copy'; }, 1200); });
    };
    dlBtn.onclick = function(){
      var blob = new Blob([text], { type: req.kind === 'json' ? 'application/json' : 'text/plain' });
      var url = URL.createObjectURL(blob);
      var a = document.createElement('a');
      a.href = url;
      a.download = (req.path.replace(/\//g, '_') || 'response').slice(1) || 'response';
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      setTimeout(function(){ URL.revokeObjectURL(url); }, 1000);
    };
  }
}

function copyText(text){
  if (navigator.clipboard && navigator.clipboard.writeText) {
    return navigator.clipboard.writeText(text);
  }
  return new Promise(function(resolve, reject){
    var ta = document.createElement('textarea');
    ta.value = text;
    ta.style.position = 'fixed';
    ta.style.opacity = '0';
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand('copy'); resolve(); }
    catch (e) { reject(e); }
    document.body.removeChild(ta);
  });
}

// Run the first endpoint automatically so the tab shows a live preview.
groupNodes[0].btns[0].click();
})();