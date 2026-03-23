# wsgi.py
from asgiref.wsgi import AsgiToWsgi
from main import app

application = AsgiToWsgi(app)