# Documentation site transparency

This page states what the deployed adacovex manual records when you read it.
The deployed manual is at <https://adacovex.readthedocs.io/en/latest/>. The
project runs no web server and no account system, so the project itself records
nothing about a reader.

The manual is a static site. Every page, style, script, and image file is built
from the repository and served as a file. The page you read now was generated
once, when the hosting provider built the documentation.

## The short answers

| Question | Answer |
|----------|--------|
| Does the project run analytics on a reader? | No. |
| Does the manual set a cookie? | No. |
| Does the manual load a script from another domain? | No. |
| Does the search box send a search word to a server? | No. |
| Does the hosting provider count page views? | Yes, in aggregate and without a cookie. |
| Does the manual show a paid advertisement? | No. |
| Does the manual show the hosting provider's flyout menu? | No. |
| Does the adacovex binary make a network call? | No. |
| Does the `--serve` dashboard leave your machine? | No. It binds to the loopback address only. |

## Search

The search box in the sidebar comes from the search index that the Sphinx HTML
builder writes. The build produces one static file that holds the words and
page names of the whole manual. Your browser loads that file and matches your
search word against it, in your own browser.

A search word never leaves your computer, and the hosting provider never
receives it. The manual keeps no list
of search words, and it sets no cookie to remember a past search.

The offline manual that `adacovex --serve` exposes at `/docs` carries the same
search index. The same search box works with no network at all.

## Traffic analytics

The hosting provider counts **page views** with its own **analytics**. It does
this for every manual it serves, and this project cannot switch it off. The
provider states that the counting is aggregate, that it uses no cookie, and
that it does not follow readers between sites. The provider also states that it
deletes its web server logs, including the IP address and the browser type,
after 10 days.

The provider obeys **Do Not Track**. If your browser sends `DNT: 1`, the
provider does not count the page view. The provider publishes its own
[privacy policy](https://docs.readthedocs.io/page/privacy-policy.html) and its
[analytics section](https://docs.readthedocs.io/page/privacy-policy.html#plausible).

The project does not add any analytics of its own. The build configuration
carries no tracking tag, so the generated pages contain no code that reports a
reader to the project or to any other company. The dashboard that `--serve`
renders carries no analytics either, and no code that calls a third party.

## Advertising and the flyout menu

This project serves no **paid advertisement**. The project owner turned that
option off in the dashboard of the hosting provider, under `Admin` >
`Advertising`. The provider also offers free **community advertisements** for
open source projects. Those messages are not paid, and the project cannot
remove them through the dashboard.

The manual does not show the **flyout menu** of the hosting provider either. The
project owner turned the flyout off under `Settings` > `Addons` > `Flyout
Menu`. The flyout holds the version selector, so the manual now serves one
version, the latest build.

## Third-party content

The manual loads no external resource. The Furo theme uses no web font, and the
build adds no video, no social button, no map, and no image from another
domain. The provider can add a link-preview popup to each page. The project
only restyles that popup for dark mode, and adds no code of its own.

## The dashboard on your machine

`adacovex --serve` starts an HTTP server that binds to the loopback address
`127.0.0.1`. No other machine on your network can reach it, and the server
accepts no connection from the internet.

The dashboard keeps one thing in your browser: the theme choice. The dashboard
stores it in the browser `localStorage` under the key `adacovex-theme`, and it
sets no cookie. The server keeps no record of a page request, and it writes no
log file. The assessment data it serves comes from the target project on your
machine, and it never leaves that machine.

## The binary and the toolchain

The adacovex binary makes no network call. It reads the files of the target
project, runs the tools on the local toolchain, and writes the reports. The
optional toolchain download is the only network activity, it happens only when
you ask for it, and it reaches the Alire and AdaCore toolchain servers. The
cache directory holds the downloaded archives under `~/.adacovex/`, and the
[global configuration page](usage/configuration.md) describes the paths and
the environment variables.

## How to examine the manual

You can check every statement on this page. Open the network panel of your
browser, then load any page of the manual. The panel shows a request for each
file of the page, and every request goes to `adacovex.readthedocs.io`.

You can also view the page source. You find no third-party script, and no
cookie is set.

## Changes to this page

This page describes the build configuration in `docs/conf.py` and the settings
of the hosting provider. The project changes this page in the same change that
alters either one. If the two ever disagree, treat this page as the defect and
report it on the
[GitHub repository](https://github.com/bladeacer/adacovex/issues).

## See also

- [Third-party notices](THIRD_PARTY_NOTICES.md) -- the documentation toolchain
  and the hosting service, with their licences.
- [Credits](CREDITS.md) -- the attributions behind the manual.
- [Bundled offline manual](usage/dashboard-docs.md) -- the same pages that
  `--serve` exposes at `/docs`, with no hosting provider in the path.
