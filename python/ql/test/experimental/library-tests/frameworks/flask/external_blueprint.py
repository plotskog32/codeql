import flask

bp3 = flask.Blueprint("bp3", __name__)

@bp3.route("/bp3/example") # $ MISSING: routeSetup="/bp3/example"
def bp3_example(): # $ MISSING: requestHandler
    return "bp 3 example"
