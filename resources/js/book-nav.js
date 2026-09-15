/*  Fill the offline manual's shared sidebar.
 *
 *  The bundled manual keeps one copy of the Furo global toctree per distinct
 *  tree, under _nav/, instead of repeating the same 8 KB of markup in all 191
 *  pages (tools/gen-docs.py writes the stubs; see the bundle review in
 *  docs/contributing/perf/benchmarks-binary-size.md).  Each page carries
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
 *  The stored asset is the container's *inner* markup, so filling the stub
 *  replaces its children in place: exactly one .sidebar-container remains.
 *  That single element is Furo's flex-stretched drawer column (the
 *  .sidebar-sticky containing block), so the sidebar sticks and
 *  .sidebar-scroll keeps its own scrollbar.  Injecting a stored container
 *  instead would nest a second .sidebar-container, collapse the sticky
 *  containing block to 100vh, and let the sidebar scroll away with the
 *  page.
 *
 *  The stored tree's links are relative to _nav/, so one tree serves pages
 *  at every directory depth; a browser would resolve markup inserted with
 *  innerHTML against the open page instead, so the script rewrites each
 *  relative URL against the store before the links go live.
 *
 *  Once the open page is marked, the script scrolls its entry into view in
 *  the drawer.  The tree is taller than the drawer now that the manual is a
 *  page per section, so the entry a reader just clicked is usually outside
 *  the drawer's own viewport when the next page loads.  Furo never moves it
 *  (its script reveals the right-hand TOC only), so the reveal is done here,
 *  in .sidebar-scroll alone: the page itself stays where it is.
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
    var open = null;
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
      if (!open) { open = links[i]; }
    }
    return open;
  }

  /*  Bring the open page's entry into the drawer's viewport, without touching
   *  the page scroll: the drawer (.sidebar-scroll) is the only scroll
   *  container involved.  An entry already comfortably in view is left
   *  alone, so the drawer never moves under a reader who just scrolled it
   *  (the manual index, the first entry, keeps the drawer at its top).
   *  Otherwise the entry lands a quarter of the way down the drawer, which
   *  keeps its caption and the entries after it on screen too.  */
  var EDGE = 16;

  function reveal(link) {
    if (!link) { return; }
    var box = link.closest(".sidebar-scroll");
    if (!box) { return; }
    var item = link.getBoundingClientRect();
    var view = box.getBoundingClientRect();
    if (item.top >= view.top + EDGE && item.bottom <= view.bottom - EDGE) {
      return;
    }
    /*  Furo sets scroll-behavior: smooth on the drawer, so a plain write
     *  would animate the reveal from the drawer's top -- and on a heavy page
     *  the animation starts seconds late, after the reader is already
     *  looking at a drawer that has not moved.  The inline override makes
     *  the write land at once, as a browser places a restored scroll.  */
    var smooth = box.style.scrollBehavior;
    box.style.scrollBehavior = "auto";
    box.scrollTop = Math.max(0, box.scrollTop + (item.top - view.top)
      - (view.height / 4));
    box.style.scrollBehavior = smooth;
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
        reveal(mark(el));
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
