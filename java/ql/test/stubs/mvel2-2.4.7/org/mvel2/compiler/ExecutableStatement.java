package org.mvel2.compiler;

import org.mvel2.integration.VariableResolverFactory;

public interface ExecutableStatement extends Accessor {
  public Object getValue(Object staticContext, VariableResolverFactory factory);
}