"""Exercise the production HTTP server with socket clients, using camera stubs."""
import http.client
import json
import socket
import subprocess
import sys

process = subprocess.Popen([sys.argv[1]], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
def get(path):
    client = http.client.HTTPConnection('127.0.0.1', 8088, timeout=5)
    client.request('GET', path)
    response = client.getresponse()
    result = response.status, response.read()
    client.close()
    return result
def stream(path):
    client = socket.create_connection(('127.0.0.1', 8088), timeout=5)
    client.sendall(('GET '+path+' HTTP/1.1\r\nHost: localhost\r\n\r\n').encode())
    reader = client.makefile('rb')
    assert reader.readline().startswith(b'HTTP/1.1 200')
    headers = b''
    while True:
        line=reader.readline()
        if line==b'\r\n': break
        assert line
        headers+=line
    assert b'boundary=frame' in headers
    assert reader.readline()==b'--frame\r\n'
    assert reader.readline()==b'Content-Type: image/jpeg\r\n'
    size=int(reader.readline().split(b':')[1])
    assert size==(1024 if path.startswith('/stream_sd') else 262144)
    assert reader.readline()==b'\r\n'
    assert reader.read(size)==bytes(size), 'Complete multipart body despite partial socket sends'
    assert reader.read(2)==b'\r\n'
    return client, reader
try:
    assert process.stdout.readline().strip()=='READY'
    status,body=get('/snapshot.jpg?t=123'); assert status==200 and body==bytes(262144)
    assert json.loads(get('/state.json?cache=1')[1])['version']=='transport-test'
    assert json.loads(get('/api/capabilities')[1])['audio'] is False
    for path in ['/action?type=tap_focus&value=0.25%2C0.75','/action/tap_focus?val=0.25%2C0.75']:
        status,body=get(path); data=json.loads(body); assert status==200 and data['type']=='tap_focus' and data['value']=='0.25,0.75'
    assert get('/action')[0]==400
    assert get('/action?type=unsupported')[0]==501
    assert get('/missing')[0]==404
    clients=[stream('/stream?cache=1'),stream('/stream_sd'),stream('/stream'),stream('/stream_sd')]
    assert get('/state.json')[0]==200, 'Control/status remains responsive with streams'
    assert get('/stream')[0]==503, 'Stream limit preserves room for controls'
    for client,reader in clients: reader.close();client.close()
    assert get('/state.json')[0]==200, 'Disconnect does not kill server (SIGPIPE)'
    process.stdin.write('r\n');process.stdin.flush()
    assert process.stdout.readline().strip()=='READY'
    assert get('/snapshot.jpg?t=456')[0]==200, 'Server restart releases listener and sockets'
    print('Production HTTP transport: snapshot query, both action routes, JSON, multipart bytes, SD, four streams, disconnect and restart PASS')
finally:
    process.communicate(input='q\n',timeout=5)
    assert process.returncode==0
