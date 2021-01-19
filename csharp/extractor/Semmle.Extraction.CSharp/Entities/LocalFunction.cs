﻿using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using System;
using System.IO;
using System.Linq;

namespace Semmle.Extraction.CSharp.Entities
{
    internal class LocalFunction : Method
    {
        private LocalFunction(Context cx, IMethodSymbol init) : base(cx, init)
        {
        }

        public override void WriteId(TextWriter trapFile)
        {
            throw new InvalidOperationException();
        }

        public override void WriteQuotedId(TextWriter trapFile)
        {
            trapFile.Write('*');
        }

        public static new LocalFunction Create(Context cx, IMethodSymbol field) => LocalFunctionFactory.Instance.CreateEntityFromSymbol(cx, field);

        private class LocalFunctionFactory : ICachedEntityFactory<IMethodSymbol, LocalFunction>
        {
            public static LocalFunctionFactory Instance { get; } = new LocalFunctionFactory();

            public LocalFunction Create(Context cx, IMethodSymbol init) => new LocalFunction(cx, init);
        }

        public override void Populate(TextWriter trapFile)
        {
            PopulateMethod(trapFile);
            PopulateModifiers(trapFile);

            var originalDefinition = IsSourceDeclaration ? this : Create(Context, symbol.OriginalDefinition);
            var returnType = Type.Create(Context, symbol.ReturnType);
            trapFile.local_functions(this, symbol.Name, returnType, originalDefinition);
            ExtractRefReturn(trapFile);
        }

        public override TrapStackBehaviour TrapStackBehaviour => TrapStackBehaviour.NeedsLabel;
    }
}
