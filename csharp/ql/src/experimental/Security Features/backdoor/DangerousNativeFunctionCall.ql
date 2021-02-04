/**
 * @name Potential dangerous use of native functions
 * @description Please review code for possible malicious intent or unsafe handling.
 *              NOTE: This query is an example of a query that may be useful for detecting potential backdoors, and Solorigate is just one such example that uses this mechanism.
 * @kind problem
 * @problem.severity warning
 * @precision low
 * @id cs/backdoor/dangerous-native-functions
 * @tags security
 *       solorigate
 */

import csharp
import semmle.code.csharp.frameworks.system.runtime.InteropServices

predicate isDangerousMethod(Method m) {
  m.getName() = "OpenProcessToken" or
  m.getName() = "OpenThreadToken" or
  m.getName() = "DuplicateToken" or
  m.getName() = "DuplicateTokenEx" or
  m.getName().matches("LogonUser%") or
  m.getName().matches("WNetAddConnection%") or
  m.getName() = "DeviceIoControl" or
  m.getName().matches("LoadLibrary%") or
  m.getName() = "GetProcAddress" or
  m.getName().matches("CreateProcess%") or
  m.getName().matches("InitiateSystemShutdown%") or
  m.getName() = "GetCurrentProcess" or
  m.getName() = "GetCurrentProcessToken" or
  m.getName() = "GetCurrentThreadToken" or
  m.getName() = "GetCurrentThreadEffectiveToken" or
  m.getName() = "OpenThreadToken" or
  m.getName() = "SetTokenInformation" or
  m.getName().matches("LookupPrivilegeValue%") or
  m.getName() = "AdjustTokenPrivileges" or
  m.getName() = "SetProcessPrivilege" or
  m.getName() = "ImpersonateLoggedOnUser" or
  m.getName().matches("Add%Ace%")
}

predicate isExternMethod(Method externMethod) {
  externMethod.isExtern()
  or
  externMethod.getAnAttribute().getType() instanceof
    SystemRuntimeInteropServicesDllImportAttributeClass
  or
  externMethod.getDeclaringType().getAnAttribute().getType() instanceof
    SystemRuntimeInteropServicesComImportAttributeClass
}

from MethodCall mc
where
  isExternMethod(mc.getTarget()) and
  isDangerousMethod(mc.getTarget())
select mc, "Call to an external method $@", mc, mc.toString()
