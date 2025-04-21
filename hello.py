import redis
from redis.exceptions import ConnectionError
import tornado.ioloop
import tornado.web
import os
from sys import exit

# Connect to Redis
try:
    redis_host = os.getenv("REDIS_HOST", "localhost")
    r = redis.Redis(
        host=redis_host,
        port=6379,
        db=0
    )
    r.set("counter", 0)
except ConnectionError:
    print("Redis server isn't running. Exiting...")
    exit()

# Read environment variable
environment = os.getenv("ENVIRONMENT", "DEV")
port = 8000

# Main request handler
class MainHandler(tornado.web.RequestHandler): 
    def get(self):
        self.render(
            "index.html",
            environment=environment,
            counter=r.incr("counter", 1)
        )

# Tornado app
class Application(tornado.web.Application):
    def __init__(self):
        handlers = [(r"/", MainHandler)]
        settings = {
            "template_path": os.path.join(
                os.path.dirname(os.path.abspath(__file__)), "templates"
            ),
            "static_path": os.path.join(
                os.path.dirname(os.path.abspath(__file__)), "static"
            ),
        }
        super().__init__(handlers, **settings)

# Run app
if __name__ == "__main__":
    app = Application()
    app.listen(port, address="0.0.0.0")
    print(f"App running at http://0.0.0.0:{port}")
    tornado.ioloop.IOLoop.current().start()

