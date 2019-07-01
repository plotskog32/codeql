// semmle-extractor-options: /r:System.Collections.Specialized.dll /r:System.Collections.dll /r:System.Linq.dll
using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Linq;

public class Collections
{
    void M1(string[] args)
    {
        var b = args.Length == 0;
        b = args.Length == 1;
        b = args.Length != 0;
        b = args.Length != 1;
        b = args.Length > 0;
        b = args.Length >= 0;
        b = args.Length >= 1;
    }

    void M2(ICollection<string> args)
    {
        var b = args.Count == 0;
        b = args.Count == 1;
        b = args.Count != 0;
        b = args.Count != 1;
        b = args.Count > 0;
        b = args.Count >= 0;
        b = args.Count >= 1;
    }

    void M3(string[] args)
    {
        var b = args.Count() == 0;
        b = args.Count() == 1;
        b = args.Count() != 0;
        b = args.Count() != 1;
        b = args.Count() > 0;
        b = args.Count() >= 0;
        b = args.Count() >= 1;
    }

    void M4(string[] args)
    {
        var b = args.Any();
    }

    void M5(List<string> args)
    {
        if (args.Count == 0)
            return;
        var x = args.ToArray();
        args.Clear();
        x = args.ToArray();
        x = new string[]{ "a", "b", "c" };
        x = x;
        x = new string[0];
        x = x;
    }

    void M6()
    {
        var x = new string[]{ "a", "b", "c" }.ToList();
        x.Clear();
        if (x.Count == 0)
        {
            x.Add("a");
            x.Add("b");
        }
    }
}

