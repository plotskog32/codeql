package com.semmle.js.extractor;

import java.io.File;
import java.io.IOException;
import java.nio.file.Path;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import com.semmle.extractor.html.HtmlPopulator;
import com.semmle.js.extractor.ExtractorConfig.Platform;
import com.semmle.js.extractor.ExtractorConfig.SourceType;
import com.semmle.js.parser.ParseError;
import com.semmle.util.data.Option;
import com.semmle.util.data.Pair;
import com.semmle.util.data.StringUtil;
import com.semmle.util.io.WholeIO;
import com.semmle.util.locations.Position;
import com.semmle.util.trap.TrapWriter;
import com.semmle.util.trap.TrapWriter.Label;

import net.htmlparser.jericho.Attribute;
import net.htmlparser.jericho.Attributes;
import net.htmlparser.jericho.Element;
import net.htmlparser.jericho.HTMLElementName;
import net.htmlparser.jericho.Segment;

/** Extractor for handling HTML and XHTML files. */
public class HTMLExtractor implements IExtractor {
  private LoCInfo locInfo = new LoCInfo(0, 0);

  private class JavaScriptHTMLElementHandler implements HtmlPopulator.ElementHandler {
    private final ScopeManager scopeManager;
    private final TextualExtractor textualExtractor;
    
    public JavaScriptHTMLElementHandler(TextualExtractor textualExtractor) {
      this.textualExtractor = textualExtractor;

      this.scopeManager =
          new ScopeManager(textualExtractor.getTrapwriter(), config.getEcmaVersion());
    }

    /*
     * Extract all JavaScript snippets appearing in (in-line) script elements and as
     * attribute values.
     */
    @Override
    public void handleElement(Element elt, HtmlPopulator.Context context) {
      if (elt.getName().equals(HTMLElementName.SCRIPT)) {
        SourceType sourceType = getScriptSourceType(elt, textualExtractor.getExtractedFile());
        if (sourceType != null) {
          // Jericho sometimes misparses empty elements, which will show up as start tags
          // ending in "/"; we manually exclude these cases to avoid spurious syntax
          // errors
          if (elt.getStartTag().getTagContent().toString().trim().endsWith("/")) return;

          Segment content = elt.getContent();
          String source = content.toString();
          boolean isTypeScript = isTypeScriptTag(elt);

          /*
           * Script blocks in XHTML files may wrap (parts of) their code inside CDATA
           * sections. We need to unwrap them in order not to confuse the JavaScript
           * parser.
           *
           * Note that CDATA sections do not nest, so they can be detected by a regular
           * expression.
           *
           * In order to preserve position information, we replace the CDATA section
           * markers with an equivalent number of whitespace characters. This will yield
           * surprising results for CDATA sections inside string literals, but those are
           * likely to be rare.
           */
          source = source.replace("<![CDATA[", "         ").replace("]]>", "   ");
          if (!source.trim().isEmpty()) {
            extractSnippet(
                TopLevelKind.INLINE_SCRIPT,
                config.withSourceType(sourceType),
                scopeManager,
                textualExtractor,
                source,
                content.getBegin(),
                isTypeScript,
                elt,
                context);
          }
        }
      } else {
        Attributes attributes = elt.getAttributes();
        // attributes can be null for directives
        if (attributes != null)
          for (Attribute attr : attributes) {
            // ignore empty attributes
            if (attr.getValue() == null || attr.getValue().isEmpty()) continue;

            String source = attr.getValue();
            int valueStart = attr.getValueSegment().getBegin();
            if (JS_ATTRIBUTE.matcher(attr.getName()).matches()) {
              extractSnippet(
                  TopLevelKind.EVENT_HANDLER,
                  config,
                  scopeManager,
                  textualExtractor,
                  source,
                  valueStart,
                  false /* isTypeScript */,
                  attr,
                  context);
            } else if (isAngularTemplateAttributeName(attr.getName())) {
              // For an attribute *ngFor="let var of EXPR", start parsing at EXPR
              int offset = 0;
              if (attr.getName().equals("*ngFor")) {
                Matcher m = ANGULAR_FOR_LOOP_DECL.matcher(source);
                if (m.matches()) {
                  String expr = m.group(2);
                  offset = m.end(2) - expr.length();
                  source = expr;
                }
              }
              extractSnippet(
                  TopLevelKind.ANGULAR_TEMPLATE,
                  config.withSourceType(SourceType.ANGULAR_TEMPLATE),
                  scopeManager,
                  textualExtractor,
                  source,
                  valueStart + offset,
                  false /* isTypeScript */,
                  attr,
                  context);
            } else if (source.startsWith("javascript:")) {
              source = source.substring(11);
              extractSnippet(
                  TopLevelKind.JAVASCRIPT_URL,
                  config,
                  scopeManager,
                  textualExtractor,
                  source,
                  valueStart + 11,
                  false /* isTypeScript */,
                  attr,
                  context);
            }
          }
      }
    }
  }

  private boolean isAngularTemplateAttributeName(String name) {
    return name.startsWith("[") && name.endsWith("]") ||
        name.startsWith("(") && name.endsWith(")") ||
        name.startsWith("*ng");
  }

  private static final Pattern ANGULAR_FOR_LOOP_DECL = Pattern.compile("^ *let +(\\w+) +of(?: +|(?!\\w))(.*)");

  /** List of HTML attributes whose value is interpreted as JavaScript. */
  private static final Pattern JS_ATTRIBUTE =
      Pattern.compile(
          "^on(abort|blur|change|(dbl)?click|error|focus|key(down|press|up)|load|mouse(down|move|out|over|up)|re(set|size)|select|submit|unload)$",
          Pattern.CASE_INSENSITIVE);

  private final ExtractorConfig config;
  private final ExtractorState state;
  private final boolean isEmbedded;

  public HTMLExtractor(ExtractorConfig config, ExtractorState state, boolean isEmbedded) {
    this.config = config.withPlatform(Platform.WEB);
    this.state = state;
    this.isEmbedded = isEmbedded;
  }

  public HTMLExtractor(ExtractorConfig config, ExtractorState state) {
    this(config, state, false);
  }

  /** Creates an HTML extractor for embedded HTML snippets. */
  public static HTMLExtractor forEmbeddedHtml(ExtractorConfig config) {
    return new HTMLExtractor(config, null, true);
  }
  
  @Override
  public LoCInfo extract(TextualExtractor textualExtractor) throws IOException {
    return extractEx(textualExtractor).snd();
  }

  public Pair<List<Label>, LoCInfo> extractEx(TextualExtractor textualExtractor) {
    // Angular templates contain attribute names that are not valid HTML/XML, such as [foo], (foo), [(foo)], and *foo.
    // Allow a large number of errors in attribute names, so the Jericho parser does not give up.
    Attributes.setDefaultMaxErrorCount(100);
    JavaScriptHTMLElementHandler eltHandler = new JavaScriptHTMLElementHandler(textualExtractor);

    LocationManager locationManager = textualExtractor.getLocationManager();
    HtmlPopulator extractor =
        new HtmlPopulator(
            this.config.getHtmlHandling(),
            textualExtractor.getSource(),
            textualExtractor.getTrapwriter(),
            locationManager.getFileLabel());

    // For efficiency, avoid building the source map if not needed (i.e. for plain HTML files).
    if (textualExtractor.hasNonTrivialSourceMap()) {
      extractor.setSourceMap(textualExtractor.getSourceMap());
    }

    List<Label> rootNodes = extractor.doit(Option.some(eltHandler));

    return Pair.make(rootNodes, locInfo);
  }

  /**
   * Deduce the {@link SourceType} with which the given <code>script</code> element should be
   * extracted, returning <code>null</code> if it cannot be determined.
   */
  private SourceType getScriptSourceType(Element script, File file) {
    String scriptType = getAttributeValueLC(script, "type");
    String scriptLanguage = getScriptLanguage(script);

    SourceType fallbackSourceType = config.getSourceType();
    if (file.getName().endsWith(".vue")) {
      fallbackSourceType = SourceType.MODULE;
    }

    if (isTypeScriptTag(script)) return fallbackSourceType;

    // if `type` and `language` are both either missing, contain the
    // string "javascript", or if `type` is the string "text/jsx", this is a plain
    // script
    if ((scriptType == null || scriptType.contains("javascript") || "text/jsx".equals(scriptType))
        && (scriptLanguage == null || scriptLanguage.contains("javascript")))
      // use default source type
      return fallbackSourceType;

    // if `type` is "text/babel", the source type depends on the `data-plugins`
    // attribute
    if ("text/babel".equals(scriptType)) {
      String plugins = getAttributeValueLC(script, "data-plugins");
      if (plugins != null && plugins.contains("transform-es2015-modules-umd")) {
        return SourceType.MODULE;
      }
      return fallbackSourceType;
    }

    // if `type` is "module", extract as module
    if ("module".equals(scriptType)) return SourceType.MODULE;

    return null;
  }

  private String getScriptLanguage(Element script) {
    String scriptLanguage = getAttributeValueLC(script, "language");

    if (scriptLanguage == null) { // Vue templates use 'lang' instead of 'language'.
      scriptLanguage = getAttributeValueLC(script, "lang");
    }
    return scriptLanguage;
  }

  private boolean isTypeScriptTag(Element script) {
    String language = getScriptLanguage(script);
    if ("ts".equals(language) || "typescript".equals(language)) return true;
    String type = getAttributeValueLC(script, "type");
    if (type != null && type.contains("typescript")) return true;
    return false;
  }

  /**
   * Get the value of attribute <code>attr</code> of element <code>elt</code> in lower case; if the
   * attribute has no value, <code>null</code> is returned.
   */
  private String getAttributeValueLC(Element elt, String attr) {
    String val = elt.getAttributeValue(attr);
    return val == null ? val : StringUtil.lc(val);
  }

  private void extractSnippet(
      TopLevelKind toplevelKind,
      ExtractorConfig config,
      ScopeManager scopeManager,
      TextualExtractor textualExtractor,
      String source,
      int offset,
      boolean isTypeScript,
      Segment parentHtmlNode,
      HtmlPopulator.Context context) {
    TrapWriter trapWriter = textualExtractor.getTrapwriter();
    LocationManager locationManager = textualExtractor.getLocationManager();
    // JavaScript AST extraction does not currently support source maps, so just set
    // line/column numbers on the location manager.
    Position pos = textualExtractor.getSourceMap().getStart(offset);
    LocationManager scriptLocationManager = locationManager.startingAt(pos.getLine(), pos.getColumn());
    if (isTypeScript) {
      if (isEmbedded) {
        return; // Do not extract files from HTML embedded in other files.
      }
      Path file = textualExtractor.getExtractedFile().toPath();
      FileSnippet snippet =
          new FileSnippet(file, pos.getLine(), pos.getColumn(), toplevelKind, config.getSourceType());
      VirtualSourceRoot vroot = config.getVirtualSourceRoot();
      // Vue files are special in that they can be imported as modules, and may only
      // contain one <script> tag.
      // For .vue files we omit the usual snippet decoration to ensure the TypeScript
      // compiler can find it.
      Path virtualFile =
          file.getFileName().toString().endsWith(".vue")
              ? vroot.toVirtualFile(file.resolveSibling(file.getFileName() + ".ts"))
              : vroot.getVirtualFileForSnippet(snippet, ".ts");
      if (virtualFile != null) {
        virtualFile = virtualFile.toAbsolutePath().normalize();
        synchronized (vroot.getLock()) {
          new WholeIO().strictwrite(virtualFile, source);
        }
        state.getSnippets().put(virtualFile, snippet);
      }
      Label topLevelLabel = ASTExtractor.makeTopLevelLabel(
          textualExtractor.getTrapwriter(),
          scriptLocationManager.getFileLabel(),
          scriptLocationManager.getStartLine(),
          scriptLocationManager.getStartColumn());
      emitTopLevelXmlNodeBinding(parentHtmlNode, topLevelLabel, context, trapWriter);
      // Note: LoC info is accounted for later, so not added here.
      return;
    }
    JSExtractor extractor = new JSExtractor(config);
    try {
      TextualExtractor tx =
          new TextualExtractor(
              trapWriter,
              scriptLocationManager,
              source,
              config.getExtractLines(),
              textualExtractor.getMetrics(),
              textualExtractor.getExtractedFile());
      Pair<Label, LoCInfo> result = extractor.extract(tx, source, toplevelKind, scopeManager);
      emitTopLevelXmlNodeBinding(parentHtmlNode, result.fst(), context, trapWriter);
      locInfo.add(result.snd());
    } catch (ParseError e) {
      e.setPosition(scriptLocationManager.translatePosition(e.getPosition()));
      throw e.asUserError();
    }
  }

  private  void emitTopLevelXmlNodeBinding(Segment parentHtmlNode, Label topLevelLabel, HtmlPopulator.Context context, TrapWriter writer) {
    Label htmlNodeLabel = context.getNodeLabel(parentHtmlNode);
    writer.addTuple("toplevel_parent_xml_node", topLevelLabel, htmlNodeLabel);
  }
}
