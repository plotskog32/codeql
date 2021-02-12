import org.apache.commons.lang3.builder.Builder;
import org.apache.commons.lang3.text.StrBuilder;
import org.apache.commons.lang3.text.StrMatcher;
import org.apache.commons.lang3.text.StrTokenizer;
import java.io.StringReader;
import java.nio.CharBuffer;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

class StrBuilderTest {
    String taint() { return "tainted"; }

    void sink(Object o) {}

    void test() throws Exception {

        StrBuilder sb1 = new StrBuilder(); sb1.append(taint().toCharArray()); sink(sb1.toString()); // $hasTaintFlow=y
        StrBuilder sb2 = new StrBuilder(); sb2.append(taint().toCharArray(), 0, 0); sink(sb2.toString()); // $hasTaintFlow=y
        StrBuilder sb3 = new StrBuilder(); sb3.append(CharBuffer.wrap(taint().toCharArray())); sink(sb3.toString()); // BAD (but not detected because we don't model CharBuffer yet)
        StrBuilder sb4 = new StrBuilder(); sb4.append(CharBuffer.wrap(taint().toCharArray()), 0, 0); sink(sb4.toString()); // BAD (but not detected because we don't model CharBuffer yet)
        StrBuilder sb5 = new StrBuilder(); sb5.append((CharSequence)taint()); sink(sb5.toString()); // $hasTaintFlow=y
        StrBuilder sb6 = new StrBuilder(); sb6.append((CharSequence)taint(), 0, 0); sink(sb6.toString()); // $hasTaintFlow=y
        StrBuilder sb7 = new StrBuilder(); sb7.append((Object)taint()); sink(sb7.toString()); // $hasTaintFlow=y
        {
            StrBuilder auxsb = new StrBuilder(); auxsb.append(taint());
            StrBuilder sb8 = new StrBuilder(); sb8.append(auxsb); sink(sb8.toString()); // $hasTaintFlow=y
        }
        StrBuilder sb9 = new StrBuilder(); sb9.append(new StringBuffer(taint())); sink(sb9.toString()); // $hasTaintFlow=y
        StrBuilder sb10 = new StrBuilder(); sb10.append(new StringBuffer(taint()), 0, 0); sink(sb10.toString()); // $hasTaintFlow=y
        StrBuilder sb11 = new StrBuilder(); sb11.append(new StringBuilder(taint())); sink(sb11.toString()); // $hasTaintFlow=y
        StrBuilder sb12 = new StrBuilder(); sb12.append(new StringBuilder(taint()), 0, 0); sink(sb12.toString()); // $hasTaintFlow=y
        StrBuilder sb13 = new StrBuilder(); sb13.append(taint()); sink(sb13.toString()); // $hasTaintFlow=y
        StrBuilder sb14 = new StrBuilder(); sb14.append(taint(), 0, 0); sink(sb14.toString()); // $hasTaintFlow=y
        StrBuilder sb15 = new StrBuilder(); sb15.append(taint(), "format", "args"); sink(sb15.toString()); // $hasTaintFlow=y
        StrBuilder sb16 = new StrBuilder(); sb16.append("Format string", taint(), "args"); sink(sb16.toString()); // $hasTaintFlow=y
        {
            List<String> taintedList = new ArrayList<>();
            taintedList.add(taint());
            StrBuilder sb17 = new StrBuilder(); sb17.appendAll(taintedList); sink(sb17.toString()); // $hasTaintFlow=y
            StrBuilder sb18 = new StrBuilder(); sb18.appendAll(taintedList.iterator()); sink(sb18.toString()); // $hasTaintFlow=y
        }
        StrBuilder sb19 = new StrBuilder(); sb19.appendAll("clean", taint()); sink(sb19.toString()); // $hasTaintFlow=y
        StrBuilder sb20 = new StrBuilder(); sb20.appendAll(taint(), "clean"); sink(sb20.toString()); // $hasTaintFlow=y
        StrBuilder sb21 = new StrBuilder(); sb21.appendFixedWidthPadLeft(taint(), 0, ' '); sink(sb21.toString()); // $hasTaintFlow=y
        StrBuilder sb22 = new StrBuilder(); sb22.appendFixedWidthPadRight(taint(), 0, ' '); sink(sb22.toString()); // $hasTaintFlow=y
        StrBuilder sb23 = new StrBuilder(); sb23.appendln(taint().toCharArray()); sink(sb23.toString()); // $hasTaintFlow=y
        StrBuilder sb24 = new StrBuilder(); sb24.appendln(taint().toCharArray(), 0, 0); sink(sb24.toString()); // $hasTaintFlow=y
        StrBuilder sb25 = new StrBuilder(); sb25.appendln((Object)taint()); sink(sb25.toString()); // $hasTaintFlow=y
        {
            StrBuilder auxsb = new StrBuilder(); auxsb.appendln(taint());
            StrBuilder sb26 = new StrBuilder(); sb26.appendln(auxsb); sink(sb26.toString()); // $hasTaintFlow=y
        }
        StrBuilder sb27 = new StrBuilder(); sb27.appendln(new StringBuffer(taint())); sink(sb27.toString()); // $hasTaintFlow=y
        StrBuilder sb28 = new StrBuilder(); sb28.appendln(new StringBuffer(taint()), 0, 0); sink(sb28.toString()); // $hasTaintFlow=y
        StrBuilder sb29 = new StrBuilder(); sb29.appendln(new StringBuilder(taint())); sink(sb29.toString()); // $hasTaintFlow=y
        StrBuilder sb30 = new StrBuilder(); sb30.appendln(new StringBuilder(taint()), 0, 0); sink(sb30.toString()); // $hasTaintFlow=y
        StrBuilder sb31 = new StrBuilder(); sb31.appendln(taint()); sink(sb31.toString()); // $hasTaintFlow=y
        StrBuilder sb32 = new StrBuilder(); sb32.appendln(taint(), 0, 0); sink(sb32.toString()); // $hasTaintFlow=y
        StrBuilder sb33 = new StrBuilder(); sb33.appendln(taint(), "format", "args"); sink(sb33.toString()); // $hasTaintFlow=y
        StrBuilder sb34 = new StrBuilder(); sb34.appendln("Format string", taint(), "args"); sink(sb34.toString()); // $hasTaintFlow=y
        StrBuilder sb35 = new StrBuilder(); sb35.appendSeparator(taint()); sink(sb35.toString()); // $hasTaintFlow=y
        StrBuilder sb36 = new StrBuilder(); sb36.appendSeparator(taint(), 0); sink(sb36.toString()); // $hasTaintFlow=y
        StrBuilder sb37 = new StrBuilder(); sb37.appendSeparator(taint(), "default"); sink(sb37.toString()); // $hasTaintFlow=y
        StrBuilder sb38 = new StrBuilder(); sb38.appendSeparator("", taint()); sink(sb38.toString()); // $hasTaintFlow=y
        {
            StrBuilder auxsb = new StrBuilder(); auxsb.appendln(taint());
            StrBuilder sb39 = new StrBuilder(); auxsb.appendTo(sb39); sink(sb39.toString()); // $hasTaintFlow=y
        }
        {
            List<String> taintedList = new ArrayList<>();
            taintedList.add(taint());
            StrBuilder sb40 = new StrBuilder(); sb40.appendWithSeparators(taintedList, ", "); sink(sb40.toString()); // $hasTaintFlow=y
            StrBuilder sb41 = new StrBuilder(); sb41.appendWithSeparators(taintedList.iterator(), ", "); sink(sb41.toString()); // $hasTaintFlow=y
            List<String> untaintedList = new ArrayList<>();
            StrBuilder sb42 = new StrBuilder(); sb42.appendWithSeparators(untaintedList, taint()); sink(sb42.toString()); // $hasTaintFlow=y
            StrBuilder sb43 = new StrBuilder(); sb43.appendWithSeparators(untaintedList.iterator(), taint()); sink(sb43.toString()); // $hasTaintFlow=y
            String[] taintedArray = new String[] { taint() };
            String[] untaintedArray = new String[] {};
            StrBuilder sb44 = new StrBuilder(); sb44.appendWithSeparators(taintedArray, ", "); sink(sb44.toString()); // $hasTaintFlow=y
            StrBuilder sb45 = new StrBuilder(); sb45.appendWithSeparators(untaintedArray, taint()); sink(sb45.toString()); // $hasTaintFlow=y
        }
        {
            StrBuilder sb46 = new StrBuilder(); sb46.append(taint());
            char[] target = new char[100];
            sb46.asReader().read(target);
            sink(target); // $hasTaintFlow=y
        }
        StrBuilder sb47 = new StrBuilder(); sb47.append(taint()); sink(sb47.asTokenizer().next()); // $hasTaintFlow=y
        StrBuilder sb48 = new StrBuilder(); sb48.append(taint()); sink(sb48.build()); // $hasTaintFlow=y
        StrBuilder sb49 = new StrBuilder(); sb49.append(taint()); sink(sb49.getChars(null)); // $hasTaintFlow=y
        {
            StrBuilder sb50 = new StrBuilder(); sb50.append(taint());
            char[] target = new char[100];
            sb50.getChars(target);
            sink(target); // $hasTaintFlow=y
        }
        {
            StrBuilder sb51 = new StrBuilder(); sb51.append(taint());
            char[] target = new char[100];
            sb51.getChars(0, 0, target, 0);
            sink(target); // $hasTaintFlow=y
        }
        StrBuilder sb52 = new StrBuilder(); sb52.insert(0, taint().toCharArray()); sink(sb52.toString()); // $hasTaintFlow=y
        StrBuilder sb53 = new StrBuilder(); sb53.insert(0, taint().toCharArray(), 0, 0); sink(sb53.toString()); // $hasTaintFlow=y
        StrBuilder sb54 = new StrBuilder(); sb54.insert(0, taint()); sink(sb54.toString()); // $hasTaintFlow=y
        StrBuilder sb55 = new StrBuilder(); sb55.insert(0, (Object)taint()); sink(sb55.toString()); // $hasTaintFlow=y
        StrBuilder sb56 = new StrBuilder(); sb56.append(taint()); sink(sb56.leftString(0)); // $hasTaintFlow=y
        StrBuilder sb57 = new StrBuilder(); sb57.append(taint()); sink(sb57.midString(0, 0)); // $hasTaintFlow=y
        {
            StringReader reader = new StringReader(taint());
            StrBuilder sb58 = new StrBuilder(); sb58.readFrom(reader); sink(sb58.toString()); // $hasTaintFlow=y
        }
        StrBuilder sb59 = new StrBuilder(); sb59.replace(0, 0, taint()); sink(sb59.toString()); // $hasTaintFlow=y
        StrBuilder sb60 = new StrBuilder(); sb60.replace(null, taint(), 0, 0, 0); sink(sb60.toString()); // $hasTaintFlow=y
        StrBuilder sb61 = new StrBuilder(); sb61.replaceAll((StrMatcher)null, taint()); sink(sb61.toString()); // $hasTaintFlow=y
        StrBuilder sb62 = new StrBuilder(); sb62.replaceAll("search", taint()); sink(sb62.toString()); // $hasTaintFlow=y
        StrBuilder sb63 = new StrBuilder(); sb63.replaceAll(taint(), "replace"); sink(sb63.toString()); // GOOD (search string doesn't convey taint)
        StrBuilder sb64 = new StrBuilder(); sb64.replaceFirst((StrMatcher)null, taint()); sink(sb64.toString()); // $hasTaintFlow=y
        StrBuilder sb65 = new StrBuilder(); sb65.replaceFirst("search", taint()); sink(sb65.toString()); // $hasTaintFlow=y
        StrBuilder sb66 = new StrBuilder(); sb66.replaceFirst(taint(), "replace"); sink(sb66.toString()); // GOOD (search string doesn't convey taint)
        StrBuilder sb67 = new StrBuilder(); sb67.append(taint()); sink(sb67.rightString(0)); // $hasTaintFlow=y
        StrBuilder sb68 = new StrBuilder(); sb68.append(taint()); sink(sb68.subSequence(0, 0)); // $hasTaintFlow=y
        StrBuilder sb69 = new StrBuilder(); sb69.append(taint()); sink(sb69.substring(0)); // $hasTaintFlow=y
        StrBuilder sb70 = new StrBuilder(); sb70.append(taint()); sink(sb70.substring(0, 0)); // $hasTaintFlow=y
        StrBuilder sb71 = new StrBuilder(); sb71.append(taint()); sink(sb71.toCharArray()); // $hasTaintFlow=y
        StrBuilder sb72 = new StrBuilder(); sb72.append(taint()); sink(sb72.toCharArray(0, 0)); // $hasTaintFlow=y
        StrBuilder sb73 = new StrBuilder(); sb73.append(taint()); sink(sb73.toStringBuffer()); // $hasTaintFlow=y
        StrBuilder sb74 = new StrBuilder(); sb74.append(taint()); sink(sb74.toStringBuilder()); // $hasTaintFlow=y
    }

}