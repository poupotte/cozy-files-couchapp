
import sys
from requests import post
import base64
 
try:
# Python 2.6
    import json
except:
    # Prior to 2.6 requires simplejson
    import simplejson as json

def requests():
    line = sys.stdin.readline()
    yield json.loads(line)

def respond(code=200, data={}, headers={}):
    sys.stdout.write("%s\n" % json.dumps({"code": code, "json": data, "headers": headers}))
    sys.stdout.flush()

def main():
    for req in requests():
        data = {'login': req['query']['name']}
        r = post(req['query']['url'] + '/device', data=data, auth=('owner', req['query']['password']))
        respond(code=r.status_code, data=r.content)

if __name__ == "__main__":
    main()