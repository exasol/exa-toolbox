--/
CREATE OR REPLACE PYTHON3 SCALAR SCRIPT EXA_TOOLBOX.check_tcp_listener_connection(host VARCHAR(200), port INT) RETURNS VARCHAR(20) AS 
#--In order for this script to work you need to run a TCP listener on the specified host and port
#--e.g. nc -lkp 3000
#--if everything is working the logging message will be displayed on your TCP listener

import logging.handlers

class PlainTextTcpHandler(logging.handlers.SocketHandler):
    """ Sends plain text log message over TCP channel """
    def makePickle(self, record):
        message = self.formatter.format(record) + "\r\n"
        return message.encode()

def run(ctx):
        rootLogger = logging.getLogger('')
        rootLogger.setLevel(logging.DEBUG)
        socketHandler = PlainTextTcpHandler(ctx.host, ctx.port)
        socketHandler.setFormatter(logging.Formatter('%(asctime)s: %(message)s'))
        rootLogger.addHandler(socketHandler)

        rootLogger.info('>>>>>>THIS IS THE MESSAGE<<<<<<<')
        return 'OK'
/

select exa_toolbox.check_tcp_listener_connection('127.0.0.1', 3000) from dual;
