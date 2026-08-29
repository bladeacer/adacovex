// Vendored JSON / code syntax highlighter.
//
// This is the `code()` tokenizer highlighter from the tiny "yace" editor
// by Peter Solopov (https://github.com/petersolopov/yace), MIT licence,
// file `src/highlighters/code.ts` at master (v1.1.0).  It is adapted from
// ESM/TypeScript to a single plain-script binding that exposes the tokenizer
// as `window.YaceTok`, so the adacovex dashboard can use it without a build
// step.  The tokenizer logic is unchanged: rules are tried in order at every
// position, extra rules take priority over the built-in ones, and tokens are
// emitted as `<span class="yace-tok yace-tok--<type>">` elements.  Colours
// are provided by the dashboard CSS (see `resources/css/dashboard.css`), as
// yace intends -- the library only tokenizes, it never imposes colours.
//
// The API playground uses it to highlight prettified JSON responses; a JSON
// key rule (`"name":`) is passed as an extra rule that runs before the
// built-in string rule so object keys colour differently from string values.

(function(){
"use strict";

var DEFAULT_RULES = [
  { type: "com", pattern: /\/\/[^\n]*|\/\*[\s\S]*?\*\// },
  {
    type: "str",
    pattern: /`(?:\\.|[^`\\])*`|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'/,
  },
  {
    type: "kw",
    pattern:
      /\b(?:const|let|var|function|return|import|from|export|default|new|if|else|for|while|class|extends|true|false|null|undefined|async|await|this|void|interface|type|number|string)\b/,
  },
  { type: "num", pattern: /\d+\.?\d*/ },
  { type: "punc", pattern: /[{}()[\] ;,.:=>+\-*/%!<>&|?]/ },
];

function escapeHtml(value){
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function escapeAttr(value){
  return escapeHtml(value).replace(/"/g, "&quot;");
}

// The yace `code()` highlighter factory.  extraRules may be omitted.
function code(extraRules){
  var rules = (extraRules || []).concat(DEFAULT_RULES).map(function(rule){
    return {
      type: rule.type,
      // sticky flag is required for the position-anchored scan; keep the
      // caller's other flags and drop the ones we override (g, y)
      pattern: new RegExp(
        rule.pattern.source,
        rule.pattern.flags.replace(/[gy]/g, "") + "y",
      ),
    };
  });

  return function(value){
    var html = "";
    var plain = "";
    var i = 0;

    var flush = function(){
      html += escapeHtml(plain);
      plain = "";
    };

    while (i < value.length) {
      var match = rules.find(function(rule){
        rule.pattern.lastIndex = i;
        return rule.pattern.test(value);
      });

      if (!match) {
        plain += value[i];
        i += 1;
        continue;
      }

      match.pattern.lastIndex = i;
      var m = match.pattern.exec(value);
      var text = m ? m[0] : "";
      // a zero-length match (e.g. /a*/ off its char) cannot advance i; treat
      // it as a plain char so the scan never spins in place
      if (text.length === 0) {
        plain += value[i];
        i += 1;
        continue;
      }
      flush();
      html += "<span class=\"yace-tok yace-tok--" + escapeAttr(match.type)
        + "\">" + escapeHtml(text) + "</span>";
      i += text.length;
    }

    flush();
    return html;
  };
}

window.YaceTok = { code: code };
})();