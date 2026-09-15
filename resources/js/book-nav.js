/*  Fill the offline manual's shared sidebar.
 *
 *  The bundled manual keeps one copy of the Furo global toctree per distinct
 *  tree, under _nav/, instead of repeating the same 8 KB of markup in all 184
 *  pages (tools/gen-docs.py writes the stubs; see the bundle review in
 *  docs/contributing/perf/benchmarks.md).  Each page carries
 *
 *    <div class="sidebar-container" data-nav="N">
 *      <script defer src="../_static/adacovex-nav.js"></script>
 *    </div>
 *
 *  so this script reads N from the stub, fetches _nav/N.html, and puts the
 *  toctree back.  The stored tree has no current-page highlight classes --
 *  they would differ per page and block the sharing -- so the script adds
 *  them for the page that is open, which is what Furo renders inline.
 *  Navigation therefore needs JavaScript; the manual's search already does.
 *
 *  The stored tree's links are relative to _nav/, so one tree serves pages
 *  at every directory depth; a browser would resolve markup inserted with
 *  innerHTML against the open page instead, so the script rewrites each
 *  relative URL against the store before the links go live.
 */
(function () {
  "use strict";
  var me = document.currentScript ||
    document.querySelector('script[src$="adacovex-nav.js"]');
  if (!me) { return; }
  var root = me.src.replace(/[^/]*$/, "").replace(/_static\/$/, "");

  /*  Compare location paths with the directory form, so /docs, /docs/, and
   *  /docs/index.html all name the same page.  */
  function here(path) {
    return path.replace(/index\.html$/, "");
  }

  function mark(el) {
    var wanted = here(new URL(window.location.href).pathname);
    var links = el.querySelectorAll("a[href]");
    for (var i = 0; i < links.length; i += 1) {
      if (here(new URL(links[i].href).pathname) !== wanted) { continue; }
      links[i].classList.add("current");
      links[i].setAttribute("aria-current", "page");
      var node = links[i].closest("li");
      if (node) { node.classList.add("current", "current-page"); }
      while (node && node !== el) {
        if (node.tagName === "UL") { node.classList.add("current"); }
        node = node.parentElement;
      }
    }
  }

  var ABSOLUTE = /^[a-z][a-z0-9+.-]*:|^\/\//i;
  var URL_ATTRS = ["href", "src", "action"];

  /*  Resolve the stored tree's relative URLs against _nav/: the store is the
   *  directory the links were built for, and the open page is not.  Absolute
   *  URLs, protocol-relative URLs, and pure fragments are already correct.  */
  function absolutise(el) {
    var base = root + "_nav/";
    var nodes = el.querySelectorAll("[href],[src],[action]");
    for (var i = 0; i < nodes.length; i += 1) {
      for (var j = 0; j < URL_ATTRS.length; j += 1) {
        var raw = nodes[i].getAttribute(URL_ATTRS[j]);
        if (!raw || raw.charAt(0) === "#" || ABSOLUTE.test(raw)) { continue; }
        nodes[i].setAttribute(URL_ATTRS[j], new URL(raw, base).href);
      }
    }
  }

  function fill(el) {
    fetch(root + "_nav/" + el.dataset.nav + ".html")
      .then(function (response) { return response.text(); })
      .then(function (html) {
        el.innerHTML = html;
        absolutise(el);
        mark(el);
      })
      .catch(function () { /* keep the page readable without the tree */ });
  }

  function start() {
    var stubs = document.querySelectorAll("[data-nav]");
    for (var i = 0; i < stubs.length; i += 1) { fill(stubs[i]); }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start, { once: true });
  } else {
    start();
  }
}());
