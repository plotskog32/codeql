using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;

namespace Semmle.Extraction.CSharp
{
    /// <summary>
    /// Identifies the compiler and framework from the command line arguments.
    /// --compiler specifies the compiler
    /// --framework specifies the .net framework
    /// </summary>
    public class CompilerVersion
    {
        const string csc_rsp = "csc.rsp";
        readonly string specifiedFramework = null;

        /// <summary>
        /// The value specified by --compiler, or null.
        /// </summary>
        public string SpecifiedCompiler
        {
            get;
            private set;
        }

        /// <summary>
        /// Why was the candidate exe rejected as a compiler?
        /// </summary>
        public string SkipReason
        {
            get;
            private set;
        }

        /// <summary>
        /// Probes the compiler (if specified).
        /// </summary>
        /// <param name="options">The command line arguments.</param>
        public CompilerVersion(Options options)
        {
            SpecifiedCompiler = options.CompilerName;
            specifiedFramework = options.Framework;

            if (SpecifiedCompiler != null)
            {
                if (!File.Exists(SpecifiedCompiler))
                {
                    SkipExtractionBecause("the specified file does not exist");
                    return;
                }

                // Reads the file details from the .exe
                var versionInfo = FileVersionInfo.GetVersionInfo(SpecifiedCompiler);

                var compilerDir = Path.GetDirectoryName(SpecifiedCompiler);
                var known_compiler_names = new Dictionary<string, string>
                {
                    { "csc.exe", "Microsoft" },
                    { "csc2.exe", "Microsoft" },
                    { "csc.dll", "Microsoft" },
                    { "mcs.exe", "Novell" }
                };
                var mscorlib_exists = File.Exists(Path.Combine(compilerDir, "mscorlib.dll"));

                if (specifiedFramework == null && mscorlib_exists)
                {
                    specifiedFramework = compilerDir;
                }

                if (!known_compiler_names.TryGetValue(versionInfo.OriginalFilename, out var vendor))
                {
                    SkipExtractionBecause("the compiler name is not recognised");
                    return;
                }

                if (versionInfo.LegalCopyright == null || !versionInfo.LegalCopyright.Contains(vendor))
                {
                    SkipExtractionBecause($"the compiler isn't copyright {vendor}, but instead {versionInfo.LegalCopyright ?? "<null>"}");
                    return;
                }
            }

            ArgsWithResponse = AddDefaultResponse(CscRsp, options.CompilerArguments).ToArray();
        }

        void SkipExtractionBecause(string reason)
        {
            SkipExtraction = true;
            SkipReason = reason;
        }

        /// <summary>
        /// The directory containing the .Net Framework.
        /// </summary>
        public string FrameworkPath => specifiedFramework ?? RuntimeEnvironment.GetRuntimeDirectory();

        /// <summary>
        /// The file csc.rsp.
        /// </summary>
        string CscRsp => Path.Combine(FrameworkPath, csc_rsp);

        /// <summary>
        /// Should we skip extraction?
        /// Only if csc.exe was specified but it wasn't a compiler.
        /// </summary>
        public bool SkipExtraction
        {
            get;
            private set;
        }

        /// <summary>
        /// Gets additional reference directories - the compiler directory.
        /// </summary>
        public string AdditionalReferenceDirectories => SpecifiedCompiler != null ? Path.GetDirectoryName(SpecifiedCompiler) : null;

        /// <summary>
        /// Adds @csc.rsp to the argument list to mimic csc.exe.
        /// </summary>
        /// <param name="responseFile">The full pathname of csc.rsp.</param>
        /// <param name="args">The other command line arguments.</param>
        /// <returns>Modified list of arguments.</returns>
        static IEnumerable<string> AddDefaultResponse(string responseFile, IEnumerable<string> args)
        {
            return SuppressDefaultResponseFile(args) && File.Exists(responseFile) ?
                args :
                new[] { "@" + responseFile }.Concat(args);
        }

        static bool SuppressDefaultResponseFile(IEnumerable<string> args)
        {
            return args.Any(arg => new[] { "/noconfig", "-noconfig" }.Contains(arg.ToLowerInvariant()));
        }

        public readonly string[] ArgsWithResponse;
    }
}
