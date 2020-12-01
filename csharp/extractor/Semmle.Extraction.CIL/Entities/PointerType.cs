using System;
using System.Collections.Generic;
using System.IO;

namespace Semmle.Extraction.CIL.Entities
{
    internal sealed class PointerType : Type, IPointerType
    {
        private readonly Type pointee;

        public PointerType(Context cx, Type pointee) : base(cx)
        {
            this.pointee = pointee;
        }

        public override bool Equals(object? obj)
        {
            return obj is PointerType pt && pointee.Equals(pt.pointee);
        }


        public override int GetHashCode()
        {
            return pointee.GetHashCode() * 29;
        }

        public override void WriteId(TextWriter trapFile, bool inContext)
        {
            pointee.WriteId(trapFile, inContext);
            trapFile.Write('*');
        }

        public override string Name => pointee.Name + "*";

        public override Namespace? Namespace => pointee.Namespace;

        public override Type? ContainingType => pointee.ContainingType;

        public override TypeContainer Parent => pointee.Parent;

        public override int ThisTypeParameters => 0;

        public override CilTypeKind Kind => CilTypeKind.Pointer;

        public override void WriteAssemblyPrefix(TextWriter trapFile) => pointee.WriteAssemblyPrefix(trapFile);

        public override IEnumerable<Type> TypeParameters => throw new NotImplementedException();

        public override IEnumerable<Type> MethodParameters => throw new NotImplementedException();

        public override Type Construct(IEnumerable<Type> typeArguments) => throw new NotImplementedException();

        public override IEnumerable<IExtractionProduct> Contents
        {
            get
            {
                foreach (var c in base.Contents) yield return c;
                yield return Tuples.cil_pointer_type(this, pointee);
            }
        }
    }
}
