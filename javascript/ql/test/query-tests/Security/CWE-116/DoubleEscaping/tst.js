function badEncode(s) {
  return s.replace(/"/g, "&quot;")
          .replace(/'/g, "&apos;")
          .replace(/&/g, "&amp;");
}

function goodEncode(s) {
  return s.replace(/&/g, "&amp;")
          .replace(/"/g, "&quot;")
          .replace(/'/g, "&apos;");
}

function goodDecode(s) {
  return s.replace(/&quot;/g, "\"")
          .replace(/&apos;/g, "'")
          .replace(/&amp;/g, "&");
}

function badDecode(s) {
  return s.replace(/&amp;/g, "&")
          .replace(/&quot;/g, "\"")
          .replace(/&apos;/g, "'");
}

function cleverEncode(code) {
    return code.replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/&(?![\w\#]+;)/g, '&amp;');
}

function badDecode2(s) {
  return s.replace(/&amp;/g, "&")
          .replace(/s?ome|thin*g/g, "else")
          .replace(/&apos;/g, "'");
}

function goodDecodeInLoop(ss) {
  var res = [];
  for (var s of ss) {
    s = s.replace(/&quot;/g, "\"")
         .replace(/&apos;/g, "'")
         .replace(/&amp;/g, "&");
    res.push(s);
  }
  return res;
}

function badDecode3(s) {
  s = s.replace(/&amp;/g, "&");
  s = s.replace(/&quot;/g, "\"");
  return s.replace(/&apos;/g, "'");
}

function badUnescape(s) {
  return s.replace(/\\\\/g, '\\')
           .replace(/\\'/g, '\'')
           .replace(/\\"/g, '\"');
}

function badPercentEscape(s) {
  s = s.replace(/&/g, '%26');
  s = s.replace(/%/g, '%25');
  return s;
}
