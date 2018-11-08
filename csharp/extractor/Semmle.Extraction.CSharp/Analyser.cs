using System;
using System.Collections.Immutable;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.Diagnostics;
using System.IO;
using System.Linq;
using Semmle.Extraction.CSharp.Populators;
using System.Runtime.InteropServices;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;
using System.Diagnostics;
using Semmle.Util.Logging;
using Semmle.Util;

namespace Semmle.Extraction.CSharp
{
    /// <summary>
    /// Encapsulates a C# analysis task.
    /// </summary>
    public class Analyser : IDisposable
    {
        IExtractor extractor;

        readonly Stopwatch stopWatch = new Stopwatch();

        readonly IProgressMonitor progressMonitor;

        public readonly ILogger Logger;

        public Analyser(IProgressMonitor pm, ILogger logger)
        {
            Logger = logger;
            Logger.Log(Severity.Info, "EXTRACTION STARTING at {0}", DateTime.Now);
            stopWatch.Start();
            progressMonitor = pm;
        }

        CSharpCompilation compilation;
        Layout layout;

        /// <summary>
        /// Initialize the analyser.
        /// </summary>
        /// <param name="commandLineArguments">Arguments passed to csc.</param>
        /// <param name="compilationIn">The Roslyn compilation.</param>
        /// <param name="options">Extractor options.</param>
        /// <param name="roslynArgs">The arguments passed to Roslyn.</param>
        public void Initialize(
            CSharpCommandLineArguments commandLineArguments,
            CSharpCompilation compilationIn,
            Options options,
            string[] roslynArgs)
        {
            compilation = compilationIn;

            layout = new Layout();
            this.options = options;

            extractor = new Extraction.Extractor(false, GetOutputName(compilation, commandLineArguments), Logger);

            LogDiagnostics(roslynArgs);
            SetReferencePaths();

            CompilationErrors += FilteredDiagnostics.Count();
        }

        /// <summary>
        ///     Constructs the map from assembly string to its filename.
        ///
        ///     Roslyn doesn't record the relationship between a filename and its assembly
        ///     information, so we need to retrieve this information manually.
        /// </summary>
        void SetReferencePaths()
        {
            foreach (var reference in compilation.References.OfType<PortableExecutableReference>())
            {
                try
                {
                    var refPath = reference.FilePath;

                    /*  This method is significantly faster and more lightweight than using
                     *  System.Reflection.Assembly.ReflectionOnlyLoadFrom. It is also allows
                     *  loading the same assembly from different locations.
                     */
                    using (var pereader = new System.Reflection.PortableExecutable.PEReader(new FileStream(refPath, FileMode.Open, FileAccess.Read, FileShare.Read)))
                    {
                        var metadata = pereader.GetMetadata();
                        string assemblyIdentity;
                        unsafe
                        {
                            var reader = new System.Reflection.Metadata.MetadataReader(metadata.Pointer, metadata.Length);
                            var def = reader.GetAssemblyDefinition();
                            assemblyIdentity = reader.GetString(def.Name) + " " + def.Version;
                        }
                        extractor.SetAssemblyFile(assemblyIdentity, refPath);
                    }
                }
                catch (Exception ex)
                {
                    extractor.Message(new Message
                    {
                        exception = ex,
                        message = string.Format("Exception reading reference file {0}: {1}",
                        reference.FilePath, ex)
                    });
                }
            }
        }

        public void InitializeStandalone(CSharpCompilation compilationIn, CommonOptions options)
        {
            compilation = compilationIn;
            layout = new Layout();
            extractor = new Extraction.Extractor(true, null, Logger);
            this.options = options;
            LogDiagnostics(null);
            SetReferencePaths();
        }

        readonly HashSet<string> errorsToIgnore = new HashSet<string>
        {
            "CS7027",   // Code signing failure
            "CS1589",   // XML referencing not supported
            "CS1569"    // Error writing XML documentation
        };

        IEnumerable<Diagnostic> FilteredDiagnostics
        {
            get
            {
                return extractor == null || extractor.Standalone || compilation == null ? Enumerable.Empty<Diagnostic>() :
                    compilation.
                    GetDiagnostics().
                    Where(e => e.Severity >= DiagnosticSeverity.Error && !errorsToIgnore.Contains(e.Id));
            }
        }

        public IEnumerable<string> MissingTypes => extractor.MissingTypes;

        public IEnumerable<string> MissingNamespaces => extractor.MissingNamespaces;

        /// <summary>
        /// Determine the path of the output dll/exe.
        /// </summary>
        /// <param name="compilation">Information about the compilation.</param>
        /// <param name="cancel">Cancellation token required.</param>
        /// <returns>The filename.</returns>
        static string GetOutputName(CSharpCompilation compilation,
            CSharpCommandLineArguments commandLineArguments)
        {
            // There's no apparent way to access the output filename from the compilation,
            // so we need to re-parse the command line arguments.

            if (commandLineArguments.OutputFileName == null)
            {
                // No output specified: Use name based on first filename
                var entry = compilation.GetEntryPoint(System.Threading.CancellationToken.None);
                if (entry == null)
                {
                    if (compilation.SyntaxTrees.Length == 0)
                        throw new ArgumentNullException("No source files seen");

                    // Probably invalid, but have a go anyway.
                    var entryPointFile = compilation.SyntaxTrees.First().FilePath;
                    return Path.ChangeExtension(entryPointFile, ".exe");
                }
                else
                {
                    var entryPointFilename = entry.Locations.First().SourceTree.FilePath;
                    return Path.ChangeExtension(entryPointFilename, ".exe");
                }
            }
            else
            {
                return Path.Combine(commandLineArguments.OutputDirectory, commandLineArguments.OutputFileName);
            }
        }

        /// <summary>
        /// Perform an analysis on a source file/syntax tree.
        /// </summary>
        /// <param name="tree">Syntax tree to analyse.</param>
        public void AnalyseTree(SyntaxTree tree)
        {
            extractionTasks.Add(() => DoExtractTree(tree));
        }

        /// <summary>
        /// Perform an analysis on an assembly.
        /// </summary>
        /// <param name="assembly">Assembly to analyse.</param>
        void AnalyseAssembly(PortableExecutableReference assembly)
        {
            // CIL first - it takes longer.
            if (options.CIL)
                extractionTasks.Add(() => DoExtractCIL(assembly));
            extractionTasks.Add(() => DoAnalyseAssembly(assembly));
        }

        readonly object progressMutex = new object();
        int taskCount = 0;

        CommonOptions options;

        static bool FileIsUpToDate(string src, string dest)
        {
            return File.Exists(dest) &&
                File.GetLastWriteTime(dest) >= File.GetLastWriteTime(src);
        }

        bool FileIsCached(string src, string dest)
        {
            return options.Cache && FileIsUpToDate(src, dest);
        }

        /// <summary>
        ///     Extract an assembly to a new trap file.
        ///     If the trap file exists, skip extraction to avoid duplicating
        ///     extraction within the snapshot.
        /// </summary>
        /// <param name="r">The assembly to extract.</param>
        void DoAnalyseAssembly(PortableExecutableReference r)
        {
            try
            {
                var stopwatch = new Stopwatch();
                stopwatch.Start();

                var assemblyPath = r.FilePath;
                var projectLayout = layout.LookupProjectOrDefault(assemblyPath);
                using (var trapWriter = projectLayout.CreateTrapWriter(Logger, assemblyPath, true))
                {
                    var skipExtraction = FileIsCached(assemblyPath, trapWriter.TrapFile);

                    if (!skipExtraction)
                    {
                        /* Note on parallel builds:
                         *
                         * The trap writer and source archiver both perform atomic moves
                         * of the file to the final destination.
                         *
                         * If the same source file or trap file are generated concurrently
                         * (by different parallel invocations of the extractor), then
                         * last one wins.
                         *
                         * Specifically, if two assemblies are analysed concurrently in a build,
                         * then there is a small amount of duplicated work but the output should
                         * still be correct.
                         */

                        // compilation.Clone() reduces memory footprint by allowing the symbols
                        // in c to be garbage collected.
                        Compilation c = compilation.Clone();

                        var assembly = c.GetAssemblyOrModuleSymbol(r) as IAssemblySymbol;

                        if (assembly != null)
                        {
                            var cx = new Context(extractor, c, trapWriter, new AssemblyScope(assembly, assemblyPath));

                            foreach (var module in assembly.Modules)
                            {
                                AnalyseNamespace(cx, module.GlobalNamespace);
                            }

                            cx.PopulateAll();
                        }
                    }

                    ReportProgress(assemblyPath, trapWriter.TrapFile, stopwatch.Elapsed, skipExtraction ? AnalysisAction.UpToDate : AnalysisAction.Extracted);
                }
            }
            catch (Exception ex)
            {
                Logger.Log(Severity.Error, "  Unhandled exception analyzing {0}: {1}", r.FilePath, ex);
            }
        }

        void DoExtractCIL(PortableExecutableReference r)
        {
            var stopwatch = new Stopwatch();
            stopwatch.Start();
            string trapFile;
            bool extracted;
            CIL.Entities.Assembly.ExtractCIL(layout, r.FilePath, Logger, !options.Cache, options.PDB, out trapFile, out extracted);
            stopwatch.Stop();
            ReportProgress(r.FilePath, trapFile, stopwatch.Elapsed, extracted ? AnalysisAction.Extracted : AnalysisAction.UpToDate);
        }

        void AnalyseNamespace(Context cx, INamespaceSymbol ns)
        {
            foreach (var memberNamespace in ns.GetNamespaceMembers())
            {
                AnalyseNamespace(cx, memberNamespace);
            }

            foreach (var memberType in ns.GetTypeMembers())
            {
                Entities.Type.Create(cx, memberType).ExtractRecursive();
            }
        }

        /// <summary>
        ///     Enqueue all reference analysis tasks.
        /// </summary>
        public void AnalyseReferences()
        {
            foreach (var r in compilation.References.OfType<PortableExecutableReference>())
            {
                AnalyseAssembly(r);
            }
        }

        // The bulk of the extraction work, potentially executed in parallel.
        readonly List<Action> extractionTasks = new List<Action>();

        void ReportProgress(string src, string output, TimeSpan time, AnalysisAction action)
        {
            lock (progressMutex)
                progressMonitor.Analysed(++taskCount, extractionTasks.Count, src, output, time, action);
        }

        void DoExtractTree(SyntaxTree tree)
        {
            try
            {
                var stopwatch = new Stopwatch();
                stopwatch.Start();
                var sourcePath = tree.FilePath;

                var projectLayout = layout.LookupProjectOrNull(sourcePath);
                bool excluded = projectLayout == null;
                string trapPath = excluded ? "" : projectLayout.GetTrapPath(Logger, sourcePath);
                bool upToDate = false;

                if (!excluded)
                {
                    // compilation.Clone() is used to allow symbols to be garbage collected.
                    using (var trapWriter = projectLayout.CreateTrapWriter(Logger, sourcePath, false))
                    {
                        upToDate = options.Fast && FileIsUpToDate(sourcePath, trapWriter.TrapFile);

                        if (!upToDate)
                        {
                            Context cx = new Context(extractor, compilation.Clone(), trapWriter, new SourceScope(tree));
                            Populators.CompilationUnit.Extract(cx, tree.GetRoot());
                            cx.PopulateAll();
                            cx.ExtractComments(cx.CommentGenerator);
                        }
                    }
                }

                ReportProgress(sourcePath, trapPath, stopwatch.Elapsed, excluded ? AnalysisAction.Excluded : upToDate ? AnalysisAction.UpToDate : AnalysisAction.Extracted);
            }
            catch (Exception ex)
            {
                extractor.Message(new Message { exception = ex, message = string.Format("Unhandled exception processing {0}: {1}", tree.FilePath, ex), severity = Severity.Error });
            }
        }

        /// <summary>
        /// Run all extraction tasks.
        /// </summary>
        /// <param name="numberOfThreads">The number of threads to use.</param>
        public void PerformExtraction(int numberOfThreads)
        {
            Parallel.Invoke(
                new ParallelOptions { MaxDegreeOfParallelism = numberOfThreads },
                extractionTasks.ToArray());
        }

        public void Dispose()
        {
            stopWatch.Stop();
            Logger.Log(Severity.Info, "  Peak working set = {0} MB", Process.GetCurrentProcess().PeakWorkingSet64 / (1024 * 1024));

            if (TotalErrors > 0)
                Logger.Log(Severity.Info, "EXTRACTION FAILED with {0} error{1} in {2}", TotalErrors, TotalErrors == 1 ? "" : "s", stopWatch.Elapsed);
            else
                Logger.Log(Severity.Info, "EXTRACTION SUCCEEDED in {0}", stopWatch.Elapsed);

            Logger.Dispose();
        }

        /// <summary>
        /// Number of errors encountered during extraction.
        /// </summary>
        public int ExtractorErrors => extractor == null ? 0 : extractor.Errors;

        /// <summary>
        /// Number of errors encountered by the compiler.
        /// </summary>
        public int CompilationErrors { get; set; }

        /// <summary>
        /// Total number of errors reported.
        /// </summary>
        public int TotalErrors => CompilationErrors + ExtractorErrors;

        /// <summary>
        /// Logs detailed information about this invocation,
        /// in the event that errors were detected.
        /// </summary>
        /// <param name="roslynArgs">The arguments passed to Roslyn.</param>
        public void LogDiagnostics(string[] roslynArgs)
        {
            Logger.Log(Severity.Info, "  Extractor: {0}", Environment.GetCommandLineArgs().First());
            if (extractor != null)
                Logger.Log(Severity.Info, "  Extractor version: {0}", extractor.Version);

            Logger.Log(Severity.Info, "  Current working directory: {0}", Directory.GetCurrentDirectory());

            if (roslynArgs != null)
            {
                Logger.Log(Severity.Info, $"  Arguments to Roslyn: {string.Join(' ', roslynArgs)}");

                // Create a new file in the log folder.
                var argsFile = Path.Combine(Extractor.GetCSharpLogDirectory(), $"csharp.{Path.GetRandomFileName()}.txt");

                if (roslynArgs.ArchiveCommandLine(argsFile))
                    Logger.Log(Severity.Info, $"  Arguments have been written to {argsFile}");
            }

            foreach (var error in FilteredDiagnostics)
            {
                Logger.Log(Severity.Error, "  Compilation error: {0}", error);
            }

            if (FilteredDiagnostics.Any())
            {
                foreach (var reference in compilation.References)
                {
                    Logger.Log(Severity.Info, "  Resolved reference {0}", reference.Display);
                }
            }
        }
    }

    /// <summary>
    /// What action was performed when extracting a file.
    /// </summary>
    public enum AnalysisAction
    {
        Extracted,
        UpToDate,
        Excluded
    }

    /// <summary>
    /// Callback for various extraction events.
    /// (Used for display of progress).
    /// </summary>
    public interface IProgressMonitor
    {
        /// <summary>
        /// Callback that a particular item has been analysed.
        /// </summary>
        /// <param name="item">The item number being processed.</param>
        /// <param name="total">The total number of items to process.</param>
        /// <param name="source">The name of the item, e.g. a source file.</param>
        /// <param name="output">The name of the item being output, e.g. a trap file.</param>
        /// <param name="time">The time to extract the item.</param>
        /// <param name="action">What action was taken for the file.</param>
        void Analysed(int item, int total, string source, string output, TimeSpan time, AnalysisAction action);

        /// <summary>
        /// A "using namespace" directive was seen but the given
        /// namespace could not be found.
        /// Only called once for each @namespace.
        /// </summary>
        /// <param name="namespace"></param>
        void MissingNamespace(string @namespace);

        /// <summary>
        /// An ErrorType was found.
        /// Called once for each type name.
        /// </summary>
        /// <param name="type">The full/partial name of the type.</param>
        void MissingType(string type);

        /// <summary>
        /// Report a summary of missing entities.
        /// </summary>
        /// <param name="types">The number of missing types.</param>
        /// <param name="namespaces">The number of missing using namespace declarations.</param>
        void MissingSummary(int types, int namespaces);
    }
}
