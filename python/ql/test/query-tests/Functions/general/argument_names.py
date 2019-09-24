# Using name other than 'self' for first argument in methods.
# This shouldn't apply to classmethods (first argument should be 'cls' or similar)
# or static methods (first argument can be anything)


class Normal(object):

    def n_ok(self):
        pass

    @staticmethod
    def n_smethod(ok):
        pass

    # not ok
    @classmethod
    def n_cmethod(self):
        pass

    # not ok
    @classmethod
    def n_cmethod2():
        pass

    # this is allowed because it has a decorator other than @classmethod
    @classmethod
    @id
    def n_suppress(any_name):
        pass


class Class(type):

    def __init__(cls):
        pass

    def c_method(y):
        pass

    def c_ok(cls):
        pass

    @id
    def c_suppress(any_name):
        pass


class NonSelf(object):

    def __init__(x):
        pass

    def s_method(y):
        pass

    def s_method2():
        pass

    def s_ok(self):
        pass

    @staticmethod
    def s_smethod(ok):
        pass

    @classmethod
    def s_cmethod(cls):
        pass

    def s_smethod2(ok):
        pass
    s_smethod2 = staticmethod(s_smethod2)

    def s_cmethod2(cls):
        pass
    s_cmethod2 = classmethod(s_cmethod2)

#Possible FPs for non-self. ODASA-2439

class Acceptable1(object):
    def _func(f):
        return f
    _func(x)

class Acceptable2(object):
    def _func(f):
        return f

    @_func
    def meth(self):
        pass

# Handling methods defined in a different scope than the class it belongs to,
# gets problmematic since we need to show the full-path from method definition
# to actually adding it to the class. We tried to enable warnings for these in
# September 2019, but ended up sticking to the decision from ODASA-2439 (where
# results are both obvious and useful to the end-user).
def dont_care(arg):
    pass

class Acceptable3(object):

    meth = dont_care

# OK
class Meta(type):

    #__new__ is an implicit class method, so the first arg is the metaclass
    def __new__(metacls, name, bases, cls_dict):
        return super(Meta, metacls).__new__(metacls, name, bases, cls_dict)

#ODASA-6062
import zope.interface
class Z(zope.interface.Interface):

    def meth(arg):
        pass

Z().meth(0)
