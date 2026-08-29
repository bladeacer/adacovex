// REST API playground.
//
// Turns the dashboard into an interactive API explorer. The endpoint list is
// served by the backend at /api/endpoints (the single source of truth), so
// the playground always reflects the routes this instance dispatches on. Each
// endpoint renders as a clickable, searchable button grouped by purpose.
// Clicking an endpoint fetches it in the browser and previews the response:
//   - JSON endpoints are pretty-printed and syntax-highlighted with the
//     vendored yace tokenizer (window.YaceTok), with object keys coloured
//     separately from string values;
//   - SVG badge endpoints show the live image plus the raw markup;
//   - the /docs endpoint shows its plain-text response.
// A toolbar offers Copy and Download for the raw response body, so the
// playground doubles as a lightweight HTTP client without leaving the browser.
(function(){
"use strict";

var PANEL = document.getElementById('tab-api');
if (!PANEL) return;

// Runtime catalog, populated from /api/endpoints.  Each group is
// { title, endpoints:[{method,path,kind,group,description}] }.
var groupNodes = [];

var keyRule = { type:'prop', pattern: /"(\\.|[^"\\])*"(?=\s*:)/ };
var HL = (window.YaceTok && window.YaceTok.code) ? window.YaceTok.code([keyRule]) : null;

function prettyJson(s){
  try { return JSON.stringify(JSON.parse(s), null, 2); }
  catch (e) { return s; }
}

// After yace highlighting, turn quoted values that look like this server's
// endpoint paths (/api/... or /badge/...) into clickable links, so the JSON
// output side is navigable: a user can jump straight from a URL in the
// payload to the live endpoint.  Works on the highlighted HTML: a JSON string
// value renders as a yace-tok--str span, and we wrap its inner text when it
// begins with a known route prefix.
function linkifyEndpointPaths(highlighted){
  return highlighted.replace(/(yace-tok--str\">)((&#34;|&quot;)?\/api\/[^<]+|(&#34;|&quot;)?\/badge\/[^<]+|(&#34;|&quot;)?\/docs)(<\/span>)/g,
    function(_m, open, path, q1, q2, q3, close){
      var quote = q1 || q2 || q3 || '';
      var bare = path.replace(quote, '').trim();
      if (!bare) return _m;
      return open + quote + '<a class="api-json-link" href="' + bare +
        '" target="_blank" rel="noopener">' + bare + '</a>' + close;
    });
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
  'Explore the JSON API, dependency graph, SVG badges and docs endpoint ' +
  'served by this adacovex instance. Click an endpoint (or type to filter), ' +
  'then preview the live response. JSON is pretty-printed and ' +
  'syntax-highlighted with the vendored yace tokenizer. The endpoint list ' +
  'comes from /api/endpoints.');
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

function addGroup(title, endpoints){
  var gw = el('div', 'api-group');
  var titleNode = el('h3', 'api-group-title', title);
  gw.appendChild(titleNode);
  var list = el('div', 'api-endpoints');
  var btns = endpoints.map(function(e){
    var b = el('button', 'api-btn');
    b.type = 'button';
    b.appendChild(el('span', 'api-method', e.method));
    // The path is a real clickable link to the endpoint itself, so the doc
    // list doubles as navigation: clicking the path opens the raw URL, while
    // clicking elsewhere on the button still runs it live in the playground.
    var pathA = document.createElement('a');
    pathA.className = 'api-path api-path-link';
    pathA.href = e.path;
    pathA.textContent = e.path;
    pathA.setAttribute('target', '_blank');
    pathA.setAttribute('rel', 'noopener');
    pathA.title = 'Open ' + e.method + ' ' + e.path + ' in a new tab';
    pathA.setAttribute('aria-label', 'Open endpoint ' + e.path);
    pathA.addEventListener('click', function(ev){ ev.stopPropagation(); });
    b.appendChild(pathA);
    b.appendChild(el('span', 'api-desc', e.description || ''));
    b.addEventListener('click', function(){ run(e, b); });
    list.appendChild(b);
    return b;
  });
  gw.appendChild(list);
  groupsWrap.appendChild(gw);
  groupNodes.push({ el: gw, titleText: title, titleNode: titleNode,
                    list: list, endpoints: endpoints, btns: btns });
}

function filterGroups(q){
  q = q.trim().toLowerCase();
  var any = false;
  groupNodes.forEach(function(gn){
    var showGroup = false;
    gn.endpoints.forEach(function(e, idx){
      var hit = !q || (e.path + ' ' + (e.description || '') + ' ' + gn.titleText).toLowerCase().indexOf(q) !== -1;
      gn.btns[idx].style.display = hit ? '' : 'none';
      if (hit) showGroup = true;
    });
    gn.el.style.display = showGroup ? '' : 'none';
    if (showGroup) any = true;
  });
  var empty = document.getElementById('api-empty') || el('p', 'api-empty', 'No endpoints match your filter (or /api/endpoints has not loaded).');
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
  var reqLine = el('span', 'api-reqline', e.method + ' ' + e.path);
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
      if (HL) pre.innerHTML = linkifyEndpointPaths(HL(pretty));
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

// Load the endpoint catalog from the server, build the group buttons, then
// run the first endpoint so the tab always opens with a live preview.
fetch('/api/endpoints')
  .then(function(resp){ return resp.json(); })
  .then(function(data){
    var list = (data && data.endpoints) || [];
    var order = [];
    var byGroup = {};
    list.forEach(function(e){
      var g = e.group || 'Other';
      if (!byGroup[g]) { byGroup[g] = []; order.push(g); }
      byGroup[g].push(e);
    });
    order.forEach(function(g){ addGroup(g, byGroup[g]); });
    if (groupNodes.length && groupNodes[0].btns.length) {
      groupNodes[0].btns[0].click();
    }
  })
  .catch(function(){
    if (!groupNodes.length) {
      var empty = el('p', 'api-empty api-load-error', 'Could not load /api/endpoints.');
      groupsWrap.appendChild(empty);
    }
  });
})();