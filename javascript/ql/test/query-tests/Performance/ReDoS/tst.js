// NOT GOOD; attack: "_" + "__".repeat(100)
// Adapted from marked (https://github.com/markedjs/marked), which is licensed
// under the MIT license; see file marked-LICENSE.
var bad1 = /^\b_((?:__|[\s\S])+?)_\b|^\*((?:\*\*|[\s\S])+?)\*(?!\*)/;

// GOOD
// Adapted from marked (https://github.com/markedjs/marked), which is licensed
// under the MIT license; see file marked-LICENSE.
var good1 = /^\b_((?:__|[^_])+?)_\b|^\*((?:\*\*|[^*])+?)\*(?!\*)/;

// GOOD - there is no witness in the end that could cause the regexp to not match
// Adapted from brace-expansion (https://github.com/juliangruber/brace-expansion),
// which is licensed under the MIT license; see file brace-expansion-LICENSE.
var bad2 = /(.*,)+.+/;

// NOT GOOD; attack: " '" + "\\\\".repeat(100)
// Adapted from CodeMirror (https://github.com/codemirror/codemirror),
// which is licensed under the MIT license; see file CodeMirror-LICENSE.
var bad3 = /^(?:\s+(?:"(?:[^"\\]|\\\\|\\.)+"|'(?:[^'\\]|\\\\|\\.)+'|\((?:[^)\\]|\\\\|\\.)+\)))?/;

// GOOD
// Adapted from lulucms2 (https://github.com/yiifans/lulucms2).
var good2 = /\(\*(?:[\s\S]*?\(\*[\s\S]*?\*\))*[\s\S]*?\*\)/;

// GOOD
// Adapted from jest (https://github.com/facebook/jest), which is licensed
// under the MIT license; see file jest-LICENSE.
var good3 = /^ *(\S.*\|.*)\n *([-:]+ *\|[-| :]*)\n((?:.*\|.*(?:\n|$))*)\n*/;

// NOT GOOD, variant of good3; attack: "a|\n:|\n" + "||\n".repeat(100)
var bad4 = /^ *(\S.*\|.*)\n *([-:]+ *\|[-| :]*)\n((?:.*\|.*(?:\n|$))*)a/;

// NOT GOOD; attack: "/" + "\\/a".repeat(100)
// Adapted from ANodeBlog (https://github.com/gefangshuai/ANodeBlog),
// which is licensed under the Apache License 2.0; see file ANodeBlog-LICENSE.
var bad5 = /\/(?![ *])(\\\/|.)*?\/[gim]*(?=\W|$)/;

// NOT GOOD; attack: "##".repeat(100) + "\na"
// Adapted from CodeMirror (https://github.com/codemirror/codemirror),
// which is licensed under the MIT license; see file CodeMirror-LICENSE.
var bad6 = /^([\s\[\{\(]|#.*)*$/;

// GOOD
var good4 = /(\r\n|\r|\n)+/;

// GOOD because it cannot be made to fail after the loop (but we can't tell that)
var good5 = /((?:[^"']|".*?"|'.*?')*?)([(,)]|$)/;

// NOT GOOD; attack: "a" + "[]".repeat(100) + ".b\n"
// Adapted from Knockout (https://github.com/knockout/knockout), which is
// licensed under the MIT license; see file knockout-LICENSE
var bad6 = /^[\_$a-z][\_$a-z0-9]*(\[.*?\])*(\.[\_$a-z][\_$a-z0-9]*(\[.*?\])*)*$/i;

// GOOD
var good6 = /(a|.)*/;

// NOT GOOD; we cannot detect all of them due to the way we build our NFAs
var bad7 = /^([a-z]+)+$/;
var bad8 = /^([a-z]*)*$/;
var bad9 = /^([a-zA-Z0-9])(([\\-.]|[_]+)?([a-zA-Z0-9]+))*(@){1}[a-z0-9]+[.]{1}(([a-z]{2,3})|([a-z]{2,3}[.]{1}[a-z]{2,3}))$/;
var bad10 = /^(([a-z])+.)+[A-Z]([a-z])+$/;

// NOT GOOD; attack: "[" + "][".repeat(100) + "]!"
// Adapted from Prototype.js (https://github.com/prototypejs/prototype), which
// is licensed under the MIT license; see file Prototype.js-LICENSE.
var bad11 = /(([\w#:.~>+()\s-]+|\*|\[.*?\])+)\s*(,|$)/;

// NOT GOOD; attack: "'" + "\\a".repeat(100) + '"'
// Adapted from Prism (https://github.com/PrismJS/prism), which is licensed
// under the MIT license; see file Prism-LICENSE.
var bad12 = /("|')(\\?.)*?\1/g;

// NOT GOOD
var bad13 = /(b|a?b)*c/;

// NOT GOOD
var bad15 = /(a|aa?)*b/;

// GOOD
var good7 = /(.|\n)*!/;

// NOT GOOD; attack: "\n".repeat(100) + "."
var bad16 = /(.|\n)*!/s;

// GOOD
var good8 = /([\w.]+)*/;

// NOT GOOD
var bad17 = new RegExp('(a|aa?)*b');

// GOOD - not used as regexp
var good9 = '(a|aa?)*b';

// NOT GOOD
var bad18 = /(([^]|[^a])*)"/;

// GOOD - there is no witness in the end that could cause the regexp to not match
var bad19 = /([^"']+)*/g;

// NOT GOOD
var bad20 = /((.|[^a])*)"/;

// GOOD
var good10 = /((a|[^a])*)"/;

// NOT GOOD
var bad21 = /((b|[^a])*)"/;

// NOT GOOD
var bad22 = /((G|[^a])*)"/;

// NOT GOOD
var bad23 = /(([0-9]|[^a])*)"/;

// NOT GOOD
var bad24 = /(?:=(?:([!#\$%&'\*\+\-\.\^_`\|~0-9A-Za-z]+)|"((?:\\[\x00-\x7f]|[^\x00-\x08\x0a-\x1f\x7f"])*)"))?/;

// NOT GOOD
var bad25 = /"((?:\\[\x00-\x7f]|[^\x00-\x08\x0a-\x1f\x7f"])*)"/;

// GOOD
var bad26 = /"((?:\\[\x00-\x7f]|[^\x00-\x08\x0a-\x1f\x7f"\\])*)"/;

// NOT GOOD
var bad27 = /(([a-z]|[d-h])*)"/;

// NOT GOOD
var bad27 = /(([^a-z]|[^0-9])*)"/;

// NOT GOOD
var bad28 = /((\d|[0-9])*)"/;

// NOT GOOD
var bad29 = /((\s|\s)*)"/;

// NOT GOOD
var bad30 = /((\w|G)*)"/;

// GOOD
var good11 = /((\s|\d)*)"/;

// NOT GOOD
var bad31 = /((\d|\w)*)"/;

// NOT GOOD
var bad32 = /((\d|5)*)"/;

// NOT GOOD
var bad33 = /((\s|[\f])*)"/;

// NOT GOOD
var bad34 = /((\s|[\v]|\\v)*)"/;

// NOT GOOD
var bad35 = /((\f|[\f])*)"/;

// NOT GOOD
var bad36 = /((\W|\D)*)"/;

// NOT GOOD
var bad37 = /((\S|\w)*)"/;

// NOT GOOD
var bad38 = /((\S|[\w])*)"/;

// NOT GOOD
var bad39 = /((1s|[\da-z])*)"/;

// NOT GOOD
var bad40 = /((0|[\d])*)"/;

// NOT GOOD
var bad41 = /(([\d]+)*)"/;

// GOOD - there is no witness in the end that could cause the regexp to not match
var good12 = /(\d+(X\d+)?)+/;

// GOOD - there is no witness in the end that could cause the regexp to not match
var good13 = /([0-9]+(X[0-9]*)?)*/;

// GOOD - but still flagged (always matches something)
var good15 = /^([^>]+)*(>|$)/;

// NOT GOOD
var bad43 = /^([^>a]+)*(>|$)/;

// NOT GOOD
var bad44 = /(\n\s*)+$/;

// NOT GOOD
var bad45 = /^(?:\s+|#.*|\(\?#[^)]*\))*(?:[?*+]|{\d+(?:,\d*)?})/;

// NOT GOOD
var bad46 = /\{\[\s*([a-zA-Z]+)\(([a-zA-Z]+)\)((\s*([a-zA-Z]+)\: ?([ a-zA-Z{}]+),?)+)*\s*\]\}/;

// NOT GOOD
var bad47 = /(a+|b+|c+)*c/;

// NOT GOOD
var bad48 = /(((a+a?)*)+b+)/;

// NOT GOOD
var bad49 = /(a+)+bbbb/;

// GOOD
var good16 = /(a+)+aaaaa*a+/;

// NOT GOOD
var bad50 = /(a+)+aaaaa$/;

// GOOD
var good17 = /(\n+)+\n\n/;

// NOT GOOD
var bad51 = /(\n+)+\n\n$/;

// NOT GOOD
var bad52 = /([^X]+)*$/;

// NOT GOOD
var bad53 = /(([^X]b)+)*$/;

// GOOD
var good18 = /(([^X]b)+)*($|[^X]b)/;

// NOT GOOD
var bad54 = /(([^X]b)+)*($|[^X]c)/;

// GOOD
var good19 = /(.*,)+.+/;

// GOOD
var good20 = /((ab)+)*ababab/;

// GOOD
var good21 = /((ab)+)*abab(ab)*(ab)+/;

// GOOD
var good22 = /((ab)+)*/;

// NOT GOOD
var bad55 = /((ab)+)*$/;

// GOOD
var good23 = /((ab)+)*[a1][b1][a2][b2][a3][b3]/;

// NOT GOOD
var bad56 = /([\n\s]+)*(.)/;

// GOOD - any witness passes through the accept state.
var good24 = /(A*A*X)*/;

// GOOD - but still flagged (always matches something)
var good25 = /^([^>]+)*(>|$)/;

// NOT GOOD
var bad57 = /^([^>a]+)*(>|$)/;

// NOT GOOD
var bad58 = /(\n\s*)+$/;
