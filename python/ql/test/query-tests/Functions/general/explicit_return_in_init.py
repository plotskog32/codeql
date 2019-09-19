class ExplicitReturnInInit(object):

    def __init__(self):
        return self

#These are OK
class ExplicitReturnNoneInInit(object):

    def __init__(self):
        return None

class PlainReturnInInit(object):

    def __init__(self):
        return

def error():
    raise Exception()

class InitCallsError(object):

    def __init__(self):
        return error()

class InitCallsInit(InitCallsError):

    def __init__(self):
        return InitCallsError.__init__(self)

class InitIsGenerator(object):

    def __init__(self):
        yield self

#OK as it returns result of a call to super().__init__()
class InitCallsInit(InitCallsError):

    def __init__(self):
        return super(InitCallsInit, self).__init__()
