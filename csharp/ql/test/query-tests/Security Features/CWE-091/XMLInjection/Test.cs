// semmle-extractor-options: /nostdlib /noconfig /r:${env.windir}\Microsoft.NET\Framework64\v4.0.30319\mscorlib.dll  /r:${env.windir}\Microsoft.NET\Framework64\v4.0.30319\System.dll /r:${env.windir}\Microsoft.NET\Framework64\v4.0.30319\System.Web.dll /r:${env.windir}\Microsoft.NET\Framework64\v4.0.30319\System.Xml.dll

using System;
using System.Security;
using System.Web;
using System.Xml;

public class XMLInjectionHandler : IHttpHandler {
  public void ProcessRequest(HttpContext ctx) {
    string employeeName = ctx.Request.QueryString["employeeName"];

    using (XmlWriter writer = XmlWriter.Create("employees.xml"))
    {
        writer.WriteStartDocument();

        // BAD: Insert user input directly into XML
        writer.WriteRaw("<employee><name>" + employeeName + "</name></employee>");

        // GOOD: Escape user input before inserting into string
        writer.WriteRaw("<employee><name>" + SecurityElement.Escape(employeeName) + "</name></employee>");

        // GOOD: Use standard API, which automatically encodes values
        writer.WriteStartElement("Employee");
        writer.WriteElementString("Name", employeeName);
        writer.WriteEndElement();

        writer.WriteEndElement();
        writer.WriteEndDocument();
    }
  }

  public bool IsReusable {
    get {
      return true;
    }
  }
}
