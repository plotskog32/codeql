var _ = require("lodash"),
    dotty = require("dotty"),
    dottie = require("dottie"),
    R = require("ramda");

_.pick(o, s1, s2);
_.pickBy(o, s);

R.pick(s, o);
R.pickBy(s, o);
R.pickAll(s, o);

_.get(o, s);

R.path(s, o);

dottie.get(o, s);

dotty.get(o, s);
dotty.search(o, s);
