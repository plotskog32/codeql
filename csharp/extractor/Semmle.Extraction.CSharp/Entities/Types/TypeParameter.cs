using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using Semmle.Extraction.Entities;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace Semmle.Extraction.CSharp.Entities
{
    internal enum Variance
    {
        None = 0,
        Out = 1,
        In = 2
    }

    internal class TypeParameter : Type<ITypeParameterSymbol>
    {
        private TypeParameter(Context cx, ITypeParameterSymbol init)
            : base(cx, init) { }

        public override void Populate(TextWriter trapFile)
        {
            var constraints = new TypeParameterConstraints(Context);
            trapFile.type_parameter_constraints(constraints, this);

            if (Symbol.HasReferenceTypeConstraint)
                trapFile.general_type_parameter_constraints(constraints, 1);

            if (Symbol.HasValueTypeConstraint)
                trapFile.general_type_parameter_constraints(constraints, 2);

            if (Symbol.HasConstructorConstraint)
                trapFile.general_type_parameter_constraints(constraints, 3);

            if (Symbol.HasUnmanagedTypeConstraint)
                trapFile.general_type_parameter_constraints(constraints, 4);

            if (Symbol.ReferenceTypeConstraintNullableAnnotation == NullableAnnotation.Annotated)
                trapFile.general_type_parameter_constraints(constraints, 5);

            foreach (var abase in Symbol.GetAnnotatedTypeConstraints())
            {
                var t = Create(Context, abase.Symbol);
                trapFile.specific_type_parameter_constraints(constraints, t.TypeRef);
                if (!abase.HasObliviousNullability())
                    trapFile.specific_type_parameter_nullability(constraints, t.TypeRef, NullabilityEntity.Create(Context, Nullability.Create(abase)));
            }

            trapFile.types(this, Kinds.TypeKind.TYPE_PARAMETER, Symbol.Name);

            var parentNs = Namespace.Create(Context, Symbol.TypeParameterKind == TypeParameterKind.Method ? Context.Compilation.GlobalNamespace : Symbol.ContainingNamespace);
            trapFile.parent_namespace(this, parentNs);

            foreach (var l in Symbol.Locations)
            {
                trapFile.type_location(this, Context.CreateLocation(l));
            }

            if (IsSourceDeclaration)
            {
                var declSyntaxReferences = Symbol.DeclaringSyntaxReferences
                    .Select(d => d.GetSyntax())
                    .Select(s => s.Parent)
                    .Where(p => p is not null)
                    .Select(p => p!.Parent)
                    .ToArray();
                var clauses = declSyntaxReferences.OfType<MethodDeclarationSyntax>().SelectMany(m => m.ConstraintClauses);
                clauses = clauses.Concat(declSyntaxReferences.OfType<ClassDeclarationSyntax>().SelectMany(c => c.ConstraintClauses));
                clauses = clauses.Concat(declSyntaxReferences.OfType<InterfaceDeclarationSyntax>().SelectMany(c => c.ConstraintClauses));
                clauses = clauses.Concat(declSyntaxReferences.OfType<StructDeclarationSyntax>().SelectMany(c => c.ConstraintClauses));
                foreach (var clause in clauses.Where(c => c.Name.Identifier.Text == Symbol.Name))
                {
                    TypeMention.Create(Context, clause.Name, this, this);
                    foreach (var constraint in clause.Constraints.OfType<TypeConstraintSyntax>())
                    {
                        var ti = Context.GetModel(constraint).GetTypeInfo(constraint.Type);
                        var target = Type.Create(Context, ti.Type);
                        TypeMention.Create(Context, constraint.Type, this, target);
                    }
                }
            }
        }

        public static TypeParameter Create(Context cx, ITypeParameterSymbol p) =>
            TypeParameterFactory.Instance.CreateEntityFromSymbol(cx, p);

        /// <summary>
        /// The variance of this type parameter.
        /// </summary>
        public Variance Variance
        {
            get
            {
                switch (Symbol.Variance)
                {
                    case VarianceKind.None: return Variance.None;
                    case VarianceKind.Out: return Variance.Out;
                    case VarianceKind.In: return Variance.In;
                    default:
                        throw new InternalError($"Unexpected VarianceKind {Symbol.Variance}");
                }
            }
        }

        public override void WriteId(TextWriter trapFile)
        {
            string kind;
            IEntity containingEntity;
            switch (Symbol.TypeParameterKind)
            {
                case TypeParameterKind.Method:
                    kind = "methodtypeparameter";
                    containingEntity = Method.Create(Context, (IMethodSymbol)Symbol.ContainingSymbol);
                    break;
                case TypeParameterKind.Type:
                    kind = "typeparameter";
                    containingEntity = Create(Context, Symbol.ContainingType);
                    break;
                default:
                    throw new InternalError(Symbol, $"Unhandled type parameter kind {Symbol.TypeParameterKind}");
            }
            trapFile.WriteSubId(containingEntity);
            trapFile.Write('_');
            trapFile.Write(Symbol.Ordinal);
            trapFile.Write(';');
            trapFile.Write(kind);
        }

        private class TypeParameterFactory : CachedEntityFactory<ITypeParameterSymbol, TypeParameter>
        {
            public static TypeParameterFactory Instance { get; } = new TypeParameterFactory();

            public override TypeParameter Create(Context cx, ITypeParameterSymbol init) => new TypeParameter(cx, init);
        }
    }
}
