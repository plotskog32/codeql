# Improvements to Python analysis


## General improvements

> Changes that affect alerts in many files or from many queries
> For example, changes to file classification

## New queries
  | **Query** | **Tags** | **Purpose** |
  |-----------|----------|-------------|
  | Accepting unknown SSH host keys when using Paramiko (`py/paramiko-missing-host-key-validation`) | security, external/cwe/cwe-295 | Finds instances where Paramiko is configured to accept unknown host keys. Results are shown on LGTM by default. |


## Changes to existing queries

  | **Query** | **Expected impact** | **Change** |
  |-----------|---------------------|------------|

## Changes to code extraction

* *Series of bullet points*

## Changes to QL libraries

* *Series of bullet points*
