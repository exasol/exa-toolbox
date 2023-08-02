/*
    This script is to check network connectivity from an Exasol database to a host:port/path using the following steps:

	* Hostname lookup using DNS (Domain Name Service)
	* TCP connect to the resulting address
	* HTTP 1.1 request

    See more at https://exasol.my.site.com/s/article/Testing-HTTP-connections-using-python-UDF?language=en_US

*/

CREATE SCHEMA IF NOT EXISTS EXA_toolbox;

create or replace python3 scalar script webtest_py( host varchar(128), port decimal(5), URI varchar(1000) )
emits ( node_name_ip varchar(67), msg_no decimal(2), duration_seconds decimal(9,3), message varchar(512) )
as

import socket
import time
from decimal import Decimal

# define some global vars
start_time = 0.0
node_name_ip = None
channel = None
msg_no = 1

# function to emit messages including hostname and elapsed time
def message(msg):
	global node_name, start_time, channel, msg_no
	start_time_new  = time.time()
	channel.emit(node_name_ip, msg_no, Decimal(start_time_new - start_time), msg)
	msg_no += 1
	start_time = start_time_new

# test DNS resolution for given host
def check_dns(ctx):
	message( "Checking DNS for " + ctx.host )
	(h,a,i) = socket.gethostbyname_ex(ctx.host)
	message( "Name resolves to IPs " + str(i) )
	return i[0]


# test TCP connect to given host/port
def check_tcp(ctx, address):
	message( "Trying to connect to " + address + ", port " + str(ctx.port) )
	s = socket.socket(socket.AF_INET)
	s.connect( (address, int(ctx.port)) )
	message( "Connected." )
	return s


# test HTTP 1.1 protocol on connected socket
def checkHttp(ctx, sock):
	request = "GET " + ctx.URI + " HTTP/1.1\r\n" + "Host: " + ctx.host + "\r\n" + "Accept: */*\r\n" + "\r\n"
	request = request.encode('utf-8')

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
	global channel, start_time, node_name_ip
	start_time = time.time()
	channel = ctx

	node_name_ip = socket.gethostname()
	try:
		node_ip = socket.gethostbyname(node_name_ip)
		node_name_ip = node_name_ip + ' (' + node_ip + ')'
	except:
		pass


	try:
		address = check_dns(ctx)
		sock = check_tcp(ctx, address)
		checkHttp(ctx, sock)
		sock.close()

	except Exception as E:
		message( "Failed: " + str(E) )

/

-- Example:

-- select webtest_py('www.heise.de', 80, '/') from exa_loadavg order by 1,2;