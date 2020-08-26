# Add taintlib to PATH so it can be imported during runtime without any hassle
import sys; import os; sys.path.append(os.path.dirname(os.path.dirname((__file__))))
from taintlib import *

# This has no runtime impact, but allows autocomplete to work
from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from ..taintlib import *


# Actual tests

from collections import defaultdict, namedtuple
from copy import copy, deepcopy

def test_construction():
    tainted_string = TAINTED_STRING
    tainted_list = [tainted_string]
    tainted_tuple = (tainted_string,)
    tainted_set = {tainted_string} # TODO: set currently not handled
    tainted_dict = {'key': tainted_string}

    ensure_tainted(
        tainted_string,
        tainted_list,
        tainted_tuple,
        tainted_set,
        tainted_dict,
    )

    ensure_tainted(
        list(tainted_list),
        list(tainted_tuple),
        list(tainted_set), # TODO: set currently not handled
        list(tainted_dict.values()),
        list(tainted_dict.items()), # TODO: dict.items() currently not handled

        tuple(tainted_list),
        set(tainted_list),
        frozenset(tainted_list), # TODO: frozenset constructor currently not handled
    )


def test_access(x, y, z):
    tainted_list = TAINTED_LIST

    ensure_tainted(
        tainted_list[0],
        tainted_list[x],
        tainted_list[y:z],

        sorted(tainted_list),
        reversed(tainted_list),
        iter(tainted_list),
        next(iter(tainted_list)),
        copy(tainted_list),
        deepcopy(tainted_list)
    )

    a, b, c = tainted_list[0:3]
    ensure_tainted(a, b, c)

    for h in tainted_list:
        ensure_tainted(h)
    for i in reversed(tainted_list):
        ensure_tainted(i)


def test_dict_access(x):
    tainted_dict = TAINTED_DICT

    ensure_tainted(
        tainted_dict["name"],
        tainted_dict.get("name"),
        tainted_dict[x],
        tainted_dict.copy(),
    )

    for v in tainted_dict.values():
        ensure_tainted(v)
    for k, v in tainted_dict.items(): # TODO: dict.items() currently not handled
        ensure_tainted(v)


def test_named_tuple(): # TODO: namedtuple currently not handled
    Point = namedtuple('Point', ['x', 'y'])
    point = Point(TAINTED_STRING, 'safe')

    ensure_tainted(
        point[0],
        point.x,
    )

    ensure_not_tainted(
        point[1],
        point.y,
    )

    a, b = point
    ensure_tainted(a)
    ensure_not_tainted(b)


def test_defaultdict(key, x): # TODO: defaultdict currently not handled
    tainted_default_dict = defaultdict(str)
    tainted_default_dict[key] += TAINTED_STRING

    ensure_tainted(
        tainted_default_dict["name"],
        tainted_default_dict.get("name"),
        tainted_default_dict[x],
        tainted_default_dict.copy(),
    )
    for v in tainted_default_dict.values():
        ensure_tainted(v)
    for k, v in tainted_default_dict.items():
        ensure_tainted(v)


# Make tests runable

test_construction()
test_access(0, 0, 2)
test_dict_access("name")
test_named_tuple()
test_defaultdict("key", "key")
