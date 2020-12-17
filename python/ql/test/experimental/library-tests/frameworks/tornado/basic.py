import tornado.web


class BasicHandler(tornado.web.RequestHandler):
    def get(self):
        self.write("BasicHandler " + self.get_argument("xss"))

    def post(self):
        self.write("BasicHandler (POST)")


class DeepInheritance(BasicHandler):
    def get(self):
        self.write("DeepInheritance" + self.get_argument("also_xss"))


class FormHandler(tornado.web.RequestHandler):
    def post(self):
        name = self.get_body_argument("name")
        self.write(name)


class RedirectHandler(tornado.web.RequestHandler):
    def get(self):
        req = self.request
        h = req.headers
        url = h["url"]
        self.redirect(url)


class BaseReverseInheritance(tornado.web.RequestHandler):
    def get(self):
        self.write("hello from BaseReverseInheritance")


class ReverseInheritance(BaseReverseInheritance):
    pass


def make_app():
    return tornado.web.Application([
        (r"/basic", BasicHandler),
        (r"/deep", DeepInheritance),
        (r"/form", FormHandler),
        (r"/redirect", RedirectHandler),
        (r"/reverse-inheritance", ReverseInheritance),
    ])


if __name__ == "__main__":
    import tornado.ioloop

    app = make_app()
    app.listen(8888)
    tornado.ioloop.IOLoop.current().start()

    # http://localhost:8888/basic?xss=foo
    # http://localhost:8888/deep?also_xss=foo

    # curl -X POST http://localhost:8888/basic
    # curl -X POST http://localhost:8888/deep

    # curl -X POST -F "name=foo" http://localhost:8888/form
    # curl -v -H 'url: http://example.com' http://localhost:8888/redirect

    # http://localhost:8888/reverse-inheritance
