Learning CodeQL
###############

CodeQL is the code analysis platform used by security researchers to automate `variant analysis <https://semmle.com/variant-analysis>`__. 
You can use CodeQL queries to explore code and quickly find variants of security vulnerabilities and bugs. 
These queries are easy to write and share–visit the topics below and `our open source repository on GitHub <https://github.com/Semmle/ql>`__ to learn more. 
You can also try out CodeQL in the `query console <https://lgtm.com/query>`__ on `LGTM.com <https://lgtm.com>`__. 
Here, you can query open source projects directly, without having to download CodeQL databases and libraries. 

CodeQL is based on a powerful query language called QL. The following topics help you understand QL in general, as well as how to use it when analyzing code with CodeQL.

.. pull-quote::

   Important 

   If you've previously used QL, you may notice slight changes in terms we use to describe some important concepts. For more information, see our note about :doc:`Recent terminology changes <terminology-note>`.

.. toctree::
   :maxdepth: 1

   introduction-to-ql
   about-ql
   beginner/ql-tutorials
   writing-queries/writing-queries
   cpp/ql-for-cpp
   csharp/ql-for-csharp
   cobol/ql-for-cobol
   go/ql-for-go
   java/ql-for-java
   javascript/ql-for-javascript
   python/ql-for-python
   ql-training
   technical-info 

.. toctree::
   :hidden:
 
   terminology-note

Further reading
***************

- `QL language handbook <https://help.semmle.com/QL/ql-handbook/index.html>`__: A description of important concepts in QL.
- `QL language specification <https://help.semmle.com/QL/ql-spec/language.html>`__: A formal specification of QL.
