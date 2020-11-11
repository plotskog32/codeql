using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using Microsoft.CodeAnalysis.CSharp;
using Semmle.Extraction.Kinds;
using Semmle.Extraction.Entities;

namespace Semmle.Extraction.CSharp.Entities.Expressions
{
    internal partial class RecursivePattern : Expression
    {
        /// <summary>
        /// Creates and populates a recursive pattern.
        /// </summary>
        /// <param name="cx">The extraction context.</param>
        /// <param name="syntax">The syntax node of the recursive pattern.</param>
        /// <param name="parent">The parent pattern/expression.</param>
        /// <param name="child">The child index of this pattern.</param>
        /// <param name="isTopLevel">If this pattern is in the top level of a case/is. In that case, the variable and type access are populated elsewhere.</param>
        public RecursivePattern(Context cx, RecursivePatternSyntax syntax, IExpressionParentEntity parent, int child) :
            base(new ExpressionInfo(cx, Entities.NullType.Create(cx), cx.Create(syntax.GetLocation()), ExprKind.RECURSIVE_PATTERN, parent, child, false, null))
        {
            // Extract the type access
            if (syntax.Type is TypeSyntax t)
                Expressions.TypeAccess.Create(cx, t, this, 1);

            // Extract the local variable declaration
            if (syntax.Designation is VariableDesignationSyntax designation && cx.GetModel(syntax).GetDeclaredSymbol(designation) is ILocalSymbol symbol)
            {
                var type = Entities.Type.Create(cx, symbol.GetAnnotatedType());

                VariableDeclaration.Create(cx, symbol, type, null, cx.Create(syntax.GetLocation()), false, this, 0);
            }

            if (syntax.PositionalPatternClause is PositionalPatternClauseSyntax posPc)
            {
                new PositionalPattern(cx, posPc, this, 2);
            }

            if (syntax.PropertyPatternClause is PropertyPatternClauseSyntax pc)
            {
                new PropertyPattern(cx, pc, this, 3);
            }
        }
    }
}
