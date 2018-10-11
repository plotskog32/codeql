using Microsoft.CodeAnalysis.CSharp.Syntax;
using Semmle.Extraction.Kinds;

namespace Semmle.Extraction.CSharp.Entities.Expressions
{
    class Unchecked : Expression<CheckedExpressionSyntax>
    {
        Unchecked(ExpressionNodeInfo info) : base(info.SetKind(ExprKind.UNCHECKED)) { }

        public static Expression Create(ExpressionNodeInfo info) => new Unchecked(info).TryPopulate();

        protected override void Populate()
        {
            Create(cx, Syntax.Expression, this, 0);
        }
    }
}
