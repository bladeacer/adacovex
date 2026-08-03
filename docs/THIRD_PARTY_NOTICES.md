# Third-Party Notices

adacovex itself is Apache-2.0 (see `LICENSE`) and depends only on the GNAT
runtime. The following third-party components are used as tools or bundled
artifacts and are covered by their own licenses.

## GNAT / GNATprove toolchain

| Component | Version | License | Used for |
|-----------|---------|---------|----------|
| GNAT compiler (GNAT Community / FSF GNAT) | toolchain-managed | GPL-3.0-or-later (with GCC Runtime Library Exception for runtime) | Compiling adacovex and target projects |
| GNATprove | 15.1.0 | GPL-3.0-or-later | SPARK proof analysis (`covex prove`) |
| Z3 / Alt-Ergo / CVC5 solvers | bundled with GNATprove | MIT / CeCILL-C / Apache-2.0 respectively | Satisfying SPARK verification conditions |

The GNAT toolchain is **not** embedded in the adacovex release bundle.
`covex prove` resolves a gnatprove executable from (in order) `$PATH`,
`~/.adacovex/toolchain/bin/gnatprove`, or a platform toolchain download
(`adacovex-toolchain-<os>-<arch>.tar.gz` published on GitHub Releases, or the
URL in `ADACOVEX_TOOLCHAIN_URL`). The toolchain archive, when published,
contains a GPL-licensed GNAT/gnatprove distribution; distributing it requires
the end user to accept the GPL for that component.

## Acknowledgments

- The Ada_CRDT audit target (`../Ada_CRDT`) is used solely as a dogfood target.
- gnatdoc (for `make doc`), gnatformat (for `make fmt`), and Alire (`alr`)
  are external tools used during development only.

Full license texts are available at:
- GPL-3.0-or-later: https://www.gnu.org/licenses/gpl-3.0.html
- GCC Runtime Library Exception: https://www.gnu.org/licenses/gcc-exception-3.1.html
