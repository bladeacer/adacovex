/*  Reveal the open page's entry in the Furo sidebar drawer.
 *
 *  The manual is a page per section, so the global toctree is far taller
 *  than the drawer.  A reader who clicks a late entry lands on a page whose
 *  own entry sits below the drawer's fold, and the drawer stays where it
 *  was: the sidebar click looks like it went nowhere.  Furo reveals its
 *  right-hand table of contents only, so nothing else moves the drawer.
 *
 *  This script moves it.  The drawer (.sidebar-scroll) is the only scroll
 *  container involved: the page itself never moves, and the drawer alone
 *  takes the scroll offset.  An entry already comfortably in view is left
 *  alone, so the drawer does not jump under a reader who has just scrolled
 *  it.  Otherwise the entry lands a quarter of the way down the drawer,
 *  which keeps its caption and the entries after it on screen too.
 *
 *  The entry is found two ways.  Sphinx marks the open page with
 *  `li.current-page > a.current`; the manual index is the root document,
 *  which no toctree may reference, so it carries no such class and is
 *  matched by path instead.  Both lookups resolve the link against the
 *  document, so `/docs`, `/docs/`, and `/docs/index.html` agree.  A page no
 *  toctree names -- a changelog, an API-reference package, the search page --
 *  has no entry of its own, and the drawer then stays where it is.
 *
 *  The reveal runs once the document is parsed.  On a page whose sidebar is
 *  injected later (the bundled offline manual), the tree is not in the DOM
 *  yet, both lookups fail, and the script leaves the drawer alone: the
 *  injector's own reveal owns that case.
 */
(function () {
  "use strict";

  /*  Visibility tolerance in pixels.  */
  var EDGE = 16;

  /*  The directory form of a path, so /docs, /docs/, and /docs/index.html
   *  all name the same page.  */
  function here(path) {
    return path.replace(/index\.html$/, "");
  }

  function entryFor(tree) {
    var marked = tree.querySelector("li.current-page > a");
    if (marked) { return marked; }
    var wanted = here(window.location.pathname);
    var links = tree.querySelectorAll("a[href]");
    for (var i = 0; i < links.length; i += 1) {
      var raw = links[i].getAttribute("href");
      if (!raw || raw.charAt(0) === "#" || !links[i].href) { continue; }
      if (here(new URL(links[i].href).pathname) === wanted) { return links[i]; }
    }
    return null;
  }

  function reveal(entry) {
    if (!entry) { return; }
    var box = entry.closest(".sidebar-scroll");
    if (!box) { return; }
    var item = entry.getBoundingClientRect();
    var view = box.getBoundingClientRect();
    if (item.top >= view.top + EDGE && item.bottom <= view.bottom - EDGE) {
      return;
    }
    /*  Furo sets scroll-behavior: smooth on the drawer, so a plain write
     *  would animate the reveal from the drawer's top.  The inline
     *  override makes the write land at once, as a browser places a
     *  restored scroll.  */
    var smooth = box.style.scrollBehavior;
    box.style.scrollBehavior = "auto";
    box.scrollTop = Math.max(0, box.scrollTop + (item.top - view.top)
      - (view.height / 4));
    box.style.scrollBehavior = smooth;
  }

  function start() {
    var tree = document.querySelector(".sidebar-tree");
    if (!tree) { return; }
    reveal(entryFor(tree));
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start, { once: true });
  } else {
    start();
  }
}());