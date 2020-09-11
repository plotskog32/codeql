import subprocess
import json
import csv
import sys
import os

"""
This script collects CodeQL queries that are part of code scanning query packs
and prints CSV data to stdout that describes which packs contain which queries.

Errors are printed to stderr. This script requires that 'git' and 'codeql' commands
are on the PATH. It'll try to automatically set the CodeQL search path correctly,
as long as you run the script from one of the following locations:
 - anywhere from within a clone of the CodeQL Git repo
 - from the parent directory of a clone of the CodeQL Git repo (assuming 'codeql' 
   and 'codeql-go' directories both exist)
"""

# Define which languages and query packs to consider
languages = [ "cpp", "csharp", "go", "java", "javascript", "python"]
packs = [ "code-scanning", "security-and-quality", "security-extended" ]


def prefix_repo_nwo(filename):
    """
    Replaces an absolute path prefix with a GitHub repository name with owner (NWO).
    This function relies on `git` being available.

    For example:
        /home/alice/git/ql/java/ql/src/MyQuery.ql  
    becomes:
        github/codeql/java/ql/src/MyQuery.ql
     
    If we can't detect a known NWO (e.g. github/codeql, github/codeql-go), the
    path will be truncated to the root of the git repo:
        ql/java/ql/src/MyQuery.ql
    
    If the filename is not part of a Git repo, the return value is the
    same as the input value: the whole path.
    """
    dirname = os.path.dirname(filename)

    try:
        git_toplevel_dir_subp = subprocess_run(["git", "-C", dirname, "rev-parse", "--show-toplevel"])
    except:
        # Not a Git repo
        return filename
    
    git_toplevel_dir = git_toplevel_dir_subp.stdout.strip()
    
    # Detect 'github/codeql' and 'github/codeql-go' repositories by checking the remote (it's a bit
    # of a hack but will work in most cases, as long as the remotes have 'codeql' and 'codeql-go'
    # in the URL
    git_remotes = subprocess_run(["git","-C",dirname,"remote","-v"]).stdout.strip()

    if "codeql-go" in git_remotes: prefix = "github/codeql-go"
    elif "codeql" in git_remotes: prefix = "github/codeql"
    else: prefix = os.path.basename(git_toplevel_dir)

    return os.path.join(prefix, filename[len(git_toplevel_dir)+1:])


def single_spaces(input):
    """
    Workaround for https://github.com/github/codeql-coreql-team/issues/470 which causes
    some metadata strings to contain newlines and spaces without a good reason.
    """
    return " ".join(input.split())


def get_query_metadata(key, metadata, queryfile):
    """Returns query metadata or prints a warning to stderr if a particular piece of metadata is not available."""
    if key in metadata: return single_spaces(metadata[key])
    query_id = metadata['id'] if 'id' in metadata else 'unknown'
    print("Warning: no '%s' metadata for query with ID '%s' (%s)" % (key, query_id, queryfile), file=sys.stderr)
    return ""


def subprocess_run(cmd):
    """Runs a command through subprocess.run, with a few tweaks. Raises an Exception if exit code != 0."""
    return subprocess.run(cmd, capture_output=True, text=True, env=os.environ.copy(), check=True)



try: # Check for `git` on path
    subprocess_run(["git","--version"])
except Exception as e:
    print("Error: couldn't invoke 'git'. Is it on the path? Aborting.", file=sys.stderr)
    raise e

try: # Check for `codeql` on path
    subprocess_run(["codeql","--version"])
except Exception as e:
    print("Error: couldn't invoke CodeQL CLI 'codeql'. Is it on the path? Aborting.", file=sys.stderr)
    raise e

# Define CodeQL search path so it'll find the CodeQL repositories:
#  - anywhere in the current Git clone (including current working directory)
#  - the 'codeql' subdirectory of the cwd
#
# (and assumes the codeql-go repo is in a similar location)
codeql_search_path = "./codeql:./codeql-go:."   # will be extended further down
    
# Extend CodeQL search path by detecting root of the current Git repo (if any). This means that you
# can run this script from any location within the CodeQL git repository.
try:
    git_toplevel_dir = subprocess_run(["git","rev-parse","--show-toplevel"])

    # Current working directory is in a Git repo. Add it to the search path, just in case it's the CodeQL repo
    git_toplevel_dir = git_toplevel_dir.stdout.strip()
    codeql_search_path += ":" + git_toplevel_dir + ":" + git_toplevel_dir + "/../codeql-go"
except:
    # git rev-parse --show-toplevel exited with non-zero exit code. We're not in a Git repo
    pass

# Create CSV writer and write CSV header to stdout
csvwriter = csv.writer(sys.stdout)
csvwriter.writerow([
    "Query filename", "Suite", "Query name", "Query ID", 
    "Kind", "Severity", "Precision", "Tags"
])

# Iterate over all languages and packs, and resolve which queries are part of those packs
for lang in languages:
    for pack in packs:
        # Get absolute paths to queries in this pack by using 'codeql resolve queries'
        try:
            queries_subp = subprocess_run(["codeql","resolve","queries","--search-path", codeql_search_path, "%s-%s.qls" % (lang, pack)])
        except Exception as e:
            # Resolving queries might go wrong if the github/codeql and github/codeql-go repositories are not
            # on the search path.
            print(
                "Warning: couldn't find query pack '%s' for language '%s'. Do you have the right repositories in the right places (search path: '%s')?" % (pack, lang, codeql_search_path),
                file=sys.stderr
            ) 
            continue

        # Investigate metadata for every query by using 'codeql resolve metadata'
        for queryfile in queries_subp.stdout.strip().split("\n"):
            query_metadata_json = subprocess_run(["codeql","resolve","metadata",queryfile]).stdout.strip()
            
            # Turn an absolute path to a query file into an nwo-prefixed path (e.g. github/codeql/java/ql/src/....)
            queryfile_nwo = prefix_repo_nwo(queryfile)

            meta = json.loads(query_metadata_json)

            # Python's CSV writer will automatically quote fields if necessary
            csvwriter.writerow([
                queryfile_nwo, pack, 
                get_query_metadata('name', meta, queryfile_nwo),
                get_query_metadata('id', meta, queryfile_nwo),
                get_query_metadata('kind', meta, queryfile_nwo),
                get_query_metadata('problem.severity', meta, queryfile_nwo),
                get_query_metadata('precision', meta, queryfile_nwo),
                get_query_metadata('tags', meta, queryfile_nwo)
            ])
            
