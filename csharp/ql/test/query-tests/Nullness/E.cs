using System;
using System.Collections.Generic;
using System.Linq;

public class E
{
    public void Ex1(long[][][] a1, int ix, int len)
    {
        long[][] a2 = null;
        var haveA2 = ix < len && (a2 = a1[ix]) != null;
        long[] a3 = null;
        var haveA3 = haveA2 && (a3 = a2[ix]) != null; // GOOD (false positive)
        if (haveA3)
            a3[0] = 0; // GOOD (false positive)
    }

    public void Ex2(bool x, bool y)
    {
        var s1 = x ? null : "";
        var s2 = (s1 == null) ? null : "";
        if (s2 == null)
        {
            s1 = y ? null : "";
            s2 = (s1 == null) ? null : "";
        }
        if (s2 != null)
            s1.ToString(); // GOOD (false positive)
    }

    public void Ex3(IEnumerable<string> ss)
    {
        string last = null;
        foreach (var s in new string[] { "aa", "bb" })
            last = s;
        last.ToString(); // GOOD (false positive)

        last = null;
        if (ss.Any())
        {
            foreach (var s in ss)
                last = s;

            last.ToString(); // GOOD (false positive)
        }
    }

    public void Ex4(IEnumerable<string> list, int step)
    {
        int index = 0;
        var result = new List<List<string>>();
        List<string> slice = null;
        var iter = list.GetEnumerator();
        while (iter.MoveNext())
        {
            var str = iter.Current;
            if (index % step == 0)
            {
                slice = new List<string>();
                result.Add(slice);
            }
            slice.Add(str); // GOOD (false positive)
            ++index;
        }
    }

    public void Ex5(bool hasArr, int[] arr)
    {
        int arrLen = 0;
        if (hasArr)
            arrLen = arr == null ? 0 : arr.Length;

        if (arrLen > 0)
            arr[0] = 0; // GOOD (false positive)
    }

    public const int MY_CONST_A = 1;
    public const int MY_CONST_B = 2;
    public const int MY_CONST_C = 3;

    public void Ex6(int[] vals, bool b1, bool b2)
    {
        int switchguard;
        if (vals != null && b1)
            switchguard = MY_CONST_A;
        else if (vals != null && b2)
            switchguard = MY_CONST_B;
        else
            switchguard = MY_CONST_C;

        switch (switchguard)
        {
            case MY_CONST_A:
                vals[0] = 0; // GOOD
                break;
            case MY_CONST_C:
                break;
            case MY_CONST_B:
                vals[0] = 0; // GOOD
                break;
            default:
                throw new Exception();
        }
    }

    public void Ex7(int[] arr1)
    {
        int[] arr2 = null;
        if (arr1.Length > 0)
            arr2 = new int[arr1.Length];

        for (var i = 0; i < arr1.Length; i++)
            arr2[i] = arr1[i]; // GOOD (false positive)
    }

    public void Ex8(int x, int lim)
    {
        bool stop = x < 1;
        int i = 0;
        var obj = new object();
        while (!stop)
        {
            int j = 0;
            while (!stop && j < lim)
            {
                int step = (j * obj.GetHashCode()) % 10; // GOOD (false positive)
                if (step == 0)
                {
                    obj.ToString(); // GOOD
                    i += 1;
                    stop = i >= x;
                    if (!stop)
                    {
                        obj = new object();
                    }
                    else
                    {
                        obj = null;
                    }
                    continue;
                }
                j += step;
            }
        }
    }

    public void Ex9(bool cond, object obj1)
    {
        if (cond)
        {
            return;
        }
        object obj2 = obj1;
        if (obj2 != null && obj2.GetHashCode() % 5 > 2)
        {
            obj2.ToString(); // GOOD
            cond = true;
        }
        if (cond)
            obj2.ToString(); // GOOD (false positive)
    }

    public void Ex10(int[] a)
    {
        int n = a == null ? 0 : a.Length;
        for (var i = 0; i < n; i++)
        {
            int x = a[i]; // GOOD (false positive)
            if (x > 7)
                a = new int[n];
        }
    }

    public void Ex11(object obj, bool b1)
    {
        bool b2 = obj == null ? false : b1;
        if (b2 == null)
        {
            obj.ToString(); // GOOD (false positive)
        }
        if (obj == null)
        {
            b1 = true;
        }
        if (b1 == null)
        {
            obj.ToString(); // GOOD (false positive)
        }
    }

    public void Ex12(object o)
    {
        var i = o.GetHashCode(); // BAD (maybe)
        var s = o?.ToString();
    }

    public void Ex13(bool b)
    {
        var o = b ? null : "";
        o.M1(); // GOOD
        if (b)
          o.M2(); // BAD (maybe)
        else
          o.Select(x => x); // BAD (maybe)
    }

    public int Ex14(string s)
    {
        if (s is string)
          return s.Length;
        return s.GetHashCode(); // BAD (always)
    }

    public void Ex15(bool b)
    {
        var x = "";
        if (b)
            x = null;
        x.ToString(); // BAD (maybe)
        if (b)
            x.ToString(); // BAD (always)
    }

    public void Ex16(bool b)
    {
        var x = "";
        if (b)
            x = null;
        if (b)
            x.ToString(); // BAD (always)
        x.ToString(); // BAD (maybe)
    }

    public int Ex17(int? i)
    {
        return i.Value; // BAD (maybe)
    }

    public int Ex18(int? i)
    {
        return (int)i; // BAD (maybe)
    }

    public int Ex19(int? i)
    {
        if (i.HasValue)
            return i.Value; // GOOD
        return -1;
    }

    public int Ex20(int? i)
    {
        if (i != null)
            return i.Value; // GOOD
        return -1;
    }

    public int Ex21(int? i)
    {
        if (i == null)
            i = 0;
        return i.Value; // GOOD
    }

    public void Ex22()
    {
        object o = null;
        try
        {
            o = Make();
            o.ToString(); // GOOD (false positive)
        }
        finally
        {
            if (o != null)
                o.ToString(); // GOOD
        }
    }

    public void Ex23(bool b)
    {
        if (b)
            b.ToString();
        var o = Make();
        o?.ToString();
        o.ToString(); // BAD (maybe)
        if (b)
            b.ToString();
    }

    public void Ex24(bool b)
    {
        string s = b ? null : "";
        if (s?.M2() == 0)
        {
            s.ToString(); // GOOD (false positive)
        }
    }

    public bool Field;
    string Make() => Field ? null : "";
}

public static class Extensions
{
    public static void M1(this string s) { }
    public static int M2(this string s) => s.Length;
}

// semmle-extractor-options: /r:System.Linq.dll
