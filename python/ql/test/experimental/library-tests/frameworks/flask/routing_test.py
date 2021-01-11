import flask

from flask import Flask, make_response
app = Flask(__name__)


SOME_ROUTE = "/some/route"
@app.route(SOME_ROUTE) # $routeSetup="/some/route"
def some_route():  # $requestHandler
    return make_response("some_route")  # $HttpResponse


def index():  # $requestHandler
    return make_response("index")  # $HttpResponse
app.add_url_rule('/index', 'index', index)  # $routeSetup="/index"


# We don't support this yet, and I think that's OK
def later_set():  # $ MISSING: requestHandler
    return make_response("later_set")  # $HttpResponse
app.add_url_rule('/later-set', 'later_set', view_func=None)  # $routeSetup="/later-set"
app.view_functions['later_set'] = later_set

# We don't want to execute this at runtime (since program will crash). Just using
# `False` makes our analysis skip it, so here's a workaround :D
if __file__ == "False":
    @app.route(UNKNOWN_ROUTE) # $routeSetup
    def unkown_route(foo, bar):  # $requestHandler routedParameter=foo routedParameter=bar
        return make_response("unkown_route")  # $HttpResponse

# View
#
# see https://flask.palletsprojects.com/en/1.1.x/views/#basic-principle

from flask.views import View


class ShowUser(View):

    def dispatch_request(self, user_id):  # $ MISSING: requestHandler routedParameter=user_id
        return "user_id: {}".format(user_id)

app.add_url_rule("/basic/user/<int:user_id>", view_func=ShowUser.as_view('show_user')) # $routeSetup="/basic/user/<int:user_id>"


class WithoutKnownRoute1(View):
    # For handler without known route, treat all parameters as routed parameters
    # (accepting that there might be a few FPs)
    def dispatch_request(self, foo, not_routed=42):  # $ MISSING: requestHandler routedParameter=foo
        pass


# MethodView
#
# see https://flask.palletsprojects.com/en/1.1.x/views/#method-views-for-apis

from flask.views import MethodView


class UserAPI(MethodView):

    def get(self, user_id):  # $ MISSING: requestHandler routedParameter=user_id
        if user_id is None:
            # return a list of users
            pass
        else:
            # expose a single user
            pass

    def post(self):  # $ MISSING: requestHandler
        # create a new user
        pass

    def delete(self, user_id):  # $ MISSING: requestHandler routedParameter=user_id
        # delete a single user
        pass

    def put(self, user_id):  # $ MISSING: requestHandler routedParameter=user_id
        # update a single user
        pass


user_view = UserAPI.as_view("user_api")
app.add_url_rule("/users/", defaults={"user_id": None}, view_func=user_view, methods=["GET",]) # $routeSetup="/users/"
app.add_url_rule("/users/", view_func=user_view, methods=["POST",]) # $routeSetup="/users/"
app.add_url_rule("/users/<int:user_id>", view_func=user_view, methods=["GET", "PUT", "DELETE"]) # $routeSetup="/users/<int:user_id>"


class WithoutKnownRoute2(MethodView):
    # For handler without known route, treat all parameters as routed parameters
    # (accepting that there might be a few FPs)
    def get(self, foo, not_routed=42):  # $ MISSING: requestHandler routedParameter=foo
        pass


if __name__ == "__main__":
    app.run(debug=True)
