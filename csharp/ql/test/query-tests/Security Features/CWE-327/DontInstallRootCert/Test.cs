// semmle-extractor-options: /r:System.Security.Cryptography.X509Certificates.dll

using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Threading.Tasks;

namespace RootCert
{
    public class Class1
    {
        public void InstallRoorCert()
        {
            string file = "mytest.pfx"; // Contains name of certificate file
            X509Store store = new X509Store(StoreName.Root);
            store.Open(OpenFlags.ReadWrite);
            store.Add(new X509Certificate2(X509Certificate2.CreateFromCertFile(file)));
            store.Close();
        }

        public void InstallRoorCert2()
        {
            string file = "mytest.pfx"; // Contains name of certificate file
            X509Store store = new X509Store(StoreName.Root, StoreLocation.CurrentUser);
            store.Open(OpenFlags.ReadWrite);
            store.Add(new X509Certificate2(X509Certificate2.CreateFromCertFile(file)));
            store.Close();
        }

        public void InstallUserCert()
        {
            string file = "mytest.pfx"; // Contains name of certificate file
            X509Store store = new X509Store(StoreName.My);
            store.Open(OpenFlags.ReadWrite);
            store.Add(new X509Certificate2(X509Certificate2.CreateFromCertFile(file)));
            store.Close();
        }

        public void RemoveUserCert()
        {
            string file = "mytest.pfx"; // Contains name of certificate file
            X509Store store = new X509Store(StoreName.My);
            store.Open(OpenFlags.ReadWrite);
            store.Remove(new X509Certificate2(X509Certificate2.CreateFromCertFile(file)));
            store.Close();
        }

        public void RemoveRootCert()
        {
            string file = "mytest.pfx"; // Contains name of certificate file
            X509Store store = new X509Store(StoreName.Root);
            store.Open(OpenFlags.ReadWrite);
            store.Remove(new X509Certificate2(X509Certificate2.CreateFromCertFile(file)));
            store.Close();
        }

        public void InstallRoorCertRange()
        {
            string file1 = "mytest1.pfx"; // Contains name of certificate file
            string file2 = "mytest2.pfx"; // Contains name of certificate file
            var certCollection = new X509Certificate2[] { 
                new X509Certificate2(X509Certificate2.CreateFromCertFile(file1)), 
                new X509Certificate2(X509Certificate2.CreateFromCertFile(file2)),
            };
            X509Store store = new X509Store(StoreName.Root, StoreLocation.CurrentUser);
            store.Open(OpenFlags.ReadWrite);
            store.AddRange(new X509Certificate2Collection(certCollection));
            store.Close();
        }
    }
}
