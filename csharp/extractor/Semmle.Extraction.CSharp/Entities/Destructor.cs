using Microsoft.CodeAnalysis;

namespace Semmle.Extraction.CSharp.Entities
{
    class Destructor : Method
    {
        Destructor(Context cx, IMethodSymbol init)
            : base(cx, init) { }

        public override void Populate()
        {
            PopulateMethod();
            ExtractModifiers();
            ContainingType.ExtractGenerics();

            Context.Emit(Tuples.destructors(this, string.Format("~{0}", symbol.ContainingType.Name), ContainingType, OriginalDefinition(Context, this, symbol)));
            Context.Emit(Tuples.destructor_location(this, Location));
        }

        static new Destructor OriginalDefinition(Context cx, Destructor original, IMethodSymbol symbol)
        {
            return symbol.OriginalDefinition == null || Equals(symbol.OriginalDefinition, symbol) ? original : Create(cx, symbol.OriginalDefinition);
        }

        public new static Destructor Create(Context cx, IMethodSymbol symbol) =>
            DestructorFactory.Instance.CreateEntity(cx, symbol);

        class DestructorFactory : ICachedEntityFactory<IMethodSymbol, Destructor>
        {
            public static readonly DestructorFactory Instance = new DestructorFactory();

            public Destructor Create(Context cx, IMethodSymbol init) => new Destructor(cx, init);
        }
    }
}
