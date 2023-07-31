open schema toolbox;

create or replace python scalar script webtest_py( host varchar(128), port decimal(5), URI varchar(1000) )
emits ( node_ip varchar(32), seconds decimal(9,3), message varchar(512) )
as

import socket
import time
from decimal import Decimal

# define some global vars
startTime = 0.0
nodeIP = None
channel = None

# function to emit messages including hostname and elapsed time
def message(msg):
	global nodeIP, startTime, channel
	channel.emit(nodeIP, Decimal(time.time() - startTime), msg)


# test DNS resolution for given host
def checkDns(ctx):
	message( "Checking DNS for " + ctx.host )
	(h,a,i) = socket.gethostbyname_ex(ctx.host)
	message( "Name resolves to IPs " + str(i) )
	return i[0]


# test TCP connect to given host/port
def checkTcp(ctx, address):
	message( "Trying to connect to " + address + ", port " + str(ctx.port) )
	s = socket.socket(socket.AF_INET)
	s.connect( (address, int(ctx.port)) )
	message( "Connected." )
	return s


# test HTTP 1.1 protocol on connected socket
def checkHttp(ctx, sock):
	request = "GET " + ctx.URI + " HTTP/1.1\r\n" + "Host: " + ctx.host + "\r\n" + "Accept: */*\r\n" + "\r\n"

	sock.sendall(request)
	message("HTTP GET request sent")

	sock.settimeout(60)

	try:
		f = sock.makefile()
		reply = f.readline()

		message(reply)
		sock.settimeout(5)

		while reply:
			reply = f.readline()
			if reply.find(':') == -1:
				break
			message("..." + reply)
		message("End of headers")
	except:
		message("Timeout reading from socket")
		pass


# main method, not much error checking...
def run(ctx):
	global channel, startTime, nodeIP
	startTime = time.time()
	channel = ctx

	nodeIP = socket.gethostname()
	try:
		nodeIP = socket.gethostbyname(nodeIP)
	except:
		pass


	try:
		address = checkDns(ctx)
		sock = checkTcp(ctx, address)
		checkHttp(ctx, sock)
		sock.close()

	except Exception as E:
		message( "Failed: " + str(E) )

/
