/* 
The below scripts will help you synchronize database users with LDAP users. The script will search for roles that contain 
a distinguished name as a role comment and will then pull the members of this group from LDAP, create the necessary users, 
and grant permissions. When users are removed from the group in LDAP, the users will also have the role revoked from them

For more information, please see the below community article:
https://community.exasol.com/t5/database-features/synchronization-of-ldap-active-directory-groups-and-members-to/ta-p/1686

======================================
--------- Where to begin?   ----------
======================================
About:  These are suggestions to ease implementation of the LDAP Sync process.

1) At the top of each script/udf is "open schema xxxxx". Set the schema in this script,
   GET_AD_ATTRIBUTES and LDAP_HELPER. The default is to create and use the schema "EXA_TOOLBOX".
   Your use case will determine the appropriate schema. This is important, as we have 
   remove the hardcoded schemas in each of the scripts provided, as they previously were using 
   the default schema "EXA_TOOLBOX".
   
2) Information to compile:
   a) DSN Name and I.P. address of the LDAP Server, including the port. Upon initial 
      implementation, we suggest using the unsecured LDAP port. Later, you can make
      changes to implement the secured LDAP configurations.
   b) An LDAP user, and password, which has permissions to query the LDAP Server.
   c) A valid LDAP Distinguished Name record, for either a user or a group. This will be used 
     when confirming the LDAP connection and running "LDAP_HELPER" with
     the LDAP query criteria. Example for LDAP user query which "LDAP_HELPER"
     can use:
         'cn=John Doe,ou=Users,dc=example,dc=com', 'uid'

3) Ensure Exasol's EXAOperation UI has the DNS servers filled in, along with the "LDAP Server URLs"
   filled in. "DNS Server 1" (and 2) can be found on the "Network" side menu. "LDAP Server URLs"
   is visible when click on the EXASolution page, and then click on the entry under "DB Name". From 
   there, choose the "EDIT" button and then look for the "LDAP Server URLS". Exasol is configured
   to only work with 1 LDAP Server, so adding a range of servers is pointless. 
   
   ** Note: Setting the "DNS Server 1" (and 2) can be done ad-hoc, without having to
   restart the database. Setting the "LDAP Server URLS" requires you to first
   shutdown the database, choose "Edit" (see the previous paragraph), setting the
   "LDAP Server URLS", saving your changes and starting the database.
   
4) To ease implementing LDAP functionality, use the I.P. address of your LDAP Server
   when setting the EXASolution "LDAP Server URLS" and creating the LDAP Connection object
   for this script. Examples:
       "LDAP Server URLS" --> "ldap://192.168.1.155:389"
       "CREATE CONNECTION "test_ldap_server" to 'ldap://192.168.1.155:389....'
   The reasoning is to eliminate failed connections using the DNS name of the 
   LDAP Server. Out of the box, Exasol does not know of your DNS or LDAP Servers,
   and some forget to set the "DNS Server 1" (and 2) on the Network page. 
   
5) First implement the unsecured LDAP functionality, (using http prefix "ldap://" 
   ensuring the proper results, then plan to implement the secured LDAP setup. 
   It's much easier to implement in smaller tasks, than to try an implement the ideal setup all at once.
   
6) Compile this script, and "GET_AD_ATTRIBUTES" incorporating the information you compiled. 
   This will ensure core functionality is implemented. To assist with verifying LDAP connections
   and general troubleshooting, compile "LDAP_HELPER" using the information you compiled. Specifically,
   build your CONNECTION using the "CREATE CONNECTION" SQL command and set up the SQL to call
   "LDAP_HELPER" with the LDAP distinguished name entry. Examples:
       a) Build Connection:
           create or replace connection test_ldap_server to 'ldap://192.168.1.155:389' user 'cn=admin,dc=example,dc=com' identified by 'secret';
       b) Build the SQL to call "LDAP_HELPER":
           select <your_schema>.LDAP_HELPER_('TEST_LDAP_SERVER', 'cn=John Doe,ou=Users,dc=example,dc=com') ;
   
7) On a closing note, when you first test the newly implemented functionality, this script will timeout
   after 30 seconds, if a valid connection is not made. Should this happen, these are the
   most likely culprits:
   a) The LDAP I.P. address and Port are incorrect.
   b) You configured your CONNECTION using the LDAP DNS server name and missed setting
      the EXASolution UI entries "DNS Server 1". You can rebuild your CONNECTION using
      the LDAP Server I.P address and retry.
   c) There is a firewall between Exasol and the LDAP server. You can also use
      this link to build just a connection tester:
      https://github.com/exasol/exa-toolbox/blob/master/utilities/check_connectivity.sql
      if you are sure the LDAP I.P. address is correct, then maybe the port is wrong.
      Try running the "check_connectivity" SQL using a different port, such as 80.
      Here are some common well known port numbers:
            21: FTP Server.
            22: SSH Server (remote login)
            25: SMTP (mail server)
            53: Domain Name System (Bind 9 server)
            80: World Wide Web (HTTPD server)
            110: POP3 mail server.
            143: IMAP mail server.
            443: HTTP over Transport Layer Security/Secure Sockets Layer (HTTPDS server)


======================================
Change Log
======================================

Version 2.2
--------------------------------------
Changes in this version:
--------------------------------------       
 - There have been enhancements added to the LDAP scripts, 
   but these enhancements are turned off by default so you can run this 
   as-is (core faunctionality) without the enhancements.
--------------------------------------
Enhancements
--------------------------------------
 - Arguement (new): OPT_SEND_EMAIL -- > disbled by default. 
   Option to capture and send LDAP changes through email. 
   ** Requires a Python UDF MAIL_MAN.py to receive the LDAP changes and email them.
   There is a check in this script to first ensure there is a script 
   named 'MAIL_MAN' before trying to call it.
               
 - Arguement (new): OPT_WRITE_AUDIT --> disabled by default
   Option to create/write LDAP changes to reporting table.
   The table is named: LDAP_REPORT_TBL and is 
   created under the same schema as this script's schema.
               
 - In the returned record set displayed, add a new message
   if the EXAOperation "LDAP Server URL" parameter is NOT set, as 
   his will impact LDAP functionality. Once the "LDAP Server URL"
   parameter is set in EXAOperation, then there is
   no addition message. It would be annoying seeing the
   "LDAP" parameter contents displayed each time this
   script executes.
         
- Scripts GET_AD_ATTRIBUTE & LDAP_HELPER are now Python3
         
 - Remove hardcoding of CONNECTION name when calling GET_AD_ATTRIBUTES.
   Having the hardcoded CONNECTION, meant results were returned
   when the CONNECTION defined in the EXECUTE SCRIPT was invalid.
--------------------------------------  
Bugfixes:
--------------------------------------
 - Continue processing despite having an Exasol role that is not defined AD (LDAP) group entry. (Bogus entry).
 - Ignore LDAP groups that do not have a valid distinguished name.
 - Format new users with apostrophe in their CN, allowing new users like Pat O'Reilly to be created in the database.    

Version 2.1:
 - Re-arranged order of setting ldap parameters and binding based on https://www.python-ldap.org/en/python-ldap-3.3.0/reference/ldap.html

Version 2.0:
Changes in this version:
 - Created HELPER script to help debug problems with AD attributes
 - improved error handling in all Python scripts
 - Added LDAP timeout parameter to 5 seconds
 - Added comments to all scripts
 - Added enhanced error handling to the Lua script
 - Added DEBUG mode to Lua script, where all statements are rolled back at the end
 - Changed logic of SQL to only GRANT or REVOKE when role membership has changed (previously would always do it)
 - Added SQL logic to allow ALTERing a user in case the dn changes, but the username is the same
 - Removed the CASCADE option from DROP USER. The script will display an error in the output that the user cannot be dropped. This is a sign for DBA to take action
 - Changed output of script to display the query text, success/fail, and what the error message is. An error in one of the statements will no longer break the script

*/




/* Set your schema first!  Uncommnt and update the next line with the desired schema*/
create schema if not exists EXA_TOOLBOX;

/*You will need a CONECTION pointing to the LDAP Server and port. 
  Example of valid LDAP connection:
  create or replace connection test_ldap_server to 'ldap://192.168.1.155:389' user 'cn=admin,dc=manhlab,dc=com' identified by 'abc';
*/

-------------------------------------------------------------------------------------
--This script will search for the specified attribute on the given distinguished name
-------------------------------------------------------------------------------------
--/
--===========================================================================================================================================================================
CREATE OR REPLACE PYTHON3 SCALAR SCRIPT "GET_AD_ATTRIBUTE" ("LDAP_CONNECTION" VARCHAR(2000),"SEARCH_STRING" VARCHAR(2000) UTF8, "ATTR"  VARCHAR(1000),  "VERIFY" VARCHAR(10))
EMITS ("SEARCH_STRING" VARCHAR(2000) UTF8, "ATTR" VARCHAR(1000), "VAL" VARCHAR(1000) UTF8) AS
--===========================================================================================================================================================================
'''
###############################################
--------------- General READ ME  --------------
###############################################
Note: This release is now PYTHON3

Purpose: This script is designed to extract LDAP information.
About:   This version of the script underwent a refactoring and was upgraded to Python3.       

What is new in this version
--------------------------------------------
1. Added additional tests to validate the Connnection.
---------------------------------------------
  This script will end abnormally if a valid LDAP connection can not be made. Primarily,
  this will aid troubleshooting when doing a first time implentation of the LDAP Sync
  (think firewalls and forgetting to set the ldap parameter in EXAOperation).
      This script is now more aggessive with validations and no longer passively returns
  if valid LDAP data is not extracted, unless it is intentional.
---------------------------------------------
2. Conversion to Python3 includes:
---------------------------------------------
   a. Changes in handling string and byte datatypes. There are differences between 
   Python2 and Python3. What used to work in Python2 no longer works as-is in Python3.
   b. Accounting for new error message formats in Python3.
---------------------------------------------
3. Add additional documentation
---------------------------------------------
   To improve user experience with first time implementation
   and troubleshooting.
'''

import ldap
import socket           # To test LDAP connectivity and abnormally end if LDAP server is not reachable.
                        # Do not return to calling script with null results (actually empty string)
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Script Variables
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
DEBUG = False               # Flag to scrutinize the CONNECTION
results = ''                # Here is my empty string for storing LDAP data
connect_result = ''         # Hold sock.connect_ex results
abortMessage = ">>> Aborting with no action taken!"
ldap_server =''             # Variable holding the input of ctx.LDAP_CONNECTION
server = ''                 # Variable holding the extracted LDAP Server address
port = 'null'               # Variable holding the extract LDAP Port
uri=''                      # Varaible to hold input URI (url)
colon = ":"                 #IPv4 / DNS variable containing a colon
ipVersion4 = False          # Socket criteria using ipv4 address
ipVersion6 = False          # Socket criteria using ipv6 address
url_components = ['.',':']  # When validating the Host URL, we are looking for IP addr or www.example.com
                            #      (the "." period) or IPV6 with colons.
ldap_prefix  = ":\/\/"        # The connection element just before the actual LDAP Server address`
my_socket_addr_list = []    # Will use this is resolving address with socket.getaddrinfo
#######################################
# FUNCTIONS
#######################################
def validate_connection(ldap_server:str(500)) -> None:
#--------------------------------------
    #----------
    # Simplistic, but catches issue with core functionality
    #----------
    try:
        if len(ldap_server) == 0:
           raise ValueError(f"The incoming LDAP CONNECTION has invalid or missing data. The LDAP CONNECTION used was parsed into -->: '{ldap_server}'.")
    except Exception as e:
        raise ValueError("Script found an empty LDAP entry of:", ldap_server, (str(e), abortMessage))
    
    #----------
    # First, did my CONNECTION start with "ldap", as in ldap: or ldaps:
    #----------
    try:
        if ldap_server.upper()[0:4] != "LDAP":
            raise Exception(f"The CONNECTION provided {ldap_server} did not start with 'ldap'")
    except Exception as e:
        raise Exception(f"Unable to use ldap connection provided: {ldap_server}", exa.meta.script_name, (str(e), abortMessage))
    
    #----------
    # Parse port`
    #----------
    try:
        global port
        port = (ldap_server[(ldap_server.rindex(colon)+1):])
    except Exception as e:
        raise Exception(f"Error, unable to extract the  port '{port}', taken from the last ':' element in the  LDAP entry:", ldap_server, str(e), abortMessage)
        
    #----------
    # Continue editting port
    # Valid ports are 1:65535. Hence, if length port > 5 - we have unusable port
    #----------
    
    try:
        if len(str(port)) == 0 or (len(str(port)) > 5 ):
            raise Exception(f"Error, Port is missing or provided port is invalid, example of what we are expecting: 'ldap://192.168.2.155:389'. Trying to extract the port as the last element in the CONNECTION, we receieved this--> '{port}'. It's not a valid port nunber > 0, taken from the last ':' element in the  LDAP entry:",ldap_server)
    except Exception  as e:
        raise Exception(f"Error, from from the last ':' element, we expected the port in the form :389, where 389 is the actual LDAP port number. The LDAP entry provided was:",ldap_server, str(e), abortMessage)
    
    #----------
    # Edit port for being an integer and positive value > 0
    #----------    
    
    try:
        if port.isnumeric():
            port = int(port)
        else:
            raise ValueError(f"The port provided --> {port} <-- is not a valid number. The port is taken from the last element in ", ldap_server)
    except Exception as e:
        raise Exception(f"Error, the parsed port '{port}' is not a valid number > 0, taken from the last ':' element in the  LDAP entry: appears to be reading the ldap server string.", ldap_server, str(e), abortMessage)
    
    #----------
    # Parse the host
    #----------
    try:
        global server
        server = ldap_server[ldap_server.index(colon)+1:ldap_server.rindex(str(port))-1]
        server = str(server)
        if (len(server) > 1):
            if ldap_prefix.find(server[1]):
                server = server.replace('//','')
    except Exception as e:
        raise Exception(f"Error, unable to parse valid values {server}, Port: {port} from LDAP Entry:", ldap_server, str(e), abortMessage)

    #----------------------------------------
    # Validate just the server (host) extraced from the LDAP CONNECTION.
    #     Look for periods in I.P. address or DSN address, 
    #     look for colon in IPv6 address
    #----------------------------------------
    
    try:
        if [comp for comp in url_components if comp.find(str(server))]:
            pass
        else:
            raise Exception("Error, unable to extract valid values for the HOST as found in the LDAP Entry:", ldap_server, str(e), abortMessage)
    except Exception as e:
        raise Exception("Failed! server does not contain valid values for the HOST as found in the LDAP Entry:", ldap_server, str(e), abortMessage)
    
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Are we using IPv6 or IPv4
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~   
    try:
        my_socket_addr_list = list(socket.getaddrinfo(server, port, 0,0, socket.SOL_TCP))
    except Exception as e:
        raise Exception(f" Are you using DNS in the LDAP CONNECTION servername? Maybe try using I.P.address, as we have an unknown LDAP host, when using socket.getaddrinfo for server {server}, port {port} taken from the provided connection",  ldap_server , str(e), abortMessage)
    
    #----------
    ''' Extract getaddrinfo into a usable list - just the ip and port info returned
        ** Note (my_tuple[4]) contains the returned server_name
        The end game is to verify the CONNECTION is using an ipv4 address.
        We currently do not support IPv6 - and it requires different socket arguments.''' 
    #----------
    
    addr_list = []
    try:
        for my_tuple in my_socket_addr_list:
            addr_list.append(my_tuple)
    except Exception as e:
        raise Exception(f"Unable to parse my_socket_addr_list into a list. addr_list=" + str(addr_list) + " from ldap_server entry: ", ldap_server, str(e), abortMessage)
        
    #----------
    # Parse the addr_list that contained the socket.getaddrinfo response.
    #----------
    ip_info = str(addr_list[0])
    ipVersion6 = ip_info.find('AddressFamily.AF_INET6:')
    if ipVersion6 == 2:
        ipVersion6 = True
    else:
        ipVersion6 = False
        
    ipVersion4 = ip_info.find('AddressFamily.AF_INET:')
    if ipVersion4 == 2:
        ipVersion4 = True
    else:
        ipVersion4 = False

    #----------------------------------------
    # Start building a socket to then test the Host and port for reachability
    #----------------------------------------
    try:
        if ipVersion4:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM, 0)
        else:
            raise Exception(f"Failed defining our socket using {server}, as currently we only support IPv4")
    except Exception as e:
            raise Exception("Unable to build socket", exa.meta.script_name, str(e), abortMessage)
    
    #----------------------------------------
    # Set socket to timeout after 30 seconds
    #----------------------------------------
    try:
        sock.settimeout(30)
    except Exception as e:
        raise Exception("Unable to set socket timeout", exa.meta.script_name, str(e), abortMessage)
    
    #----------------------------------------
    # Make socket connection to LDAP Host and port
    #----------------------------------------
    try:
        global connect_result
        connect_result = sock.connect_ex((str(server), port))
    except Exception as e:
        if result == 11:
            raise Exception("Socket timeout...unable to connect to " + str(server) + " and port " + str(port), exa.meta.script_name, (str(e), abortMessage))
        else:
            raise Exception("Can open socket, but unable to connect to " + str(server) + " and port " + str(port), exa.meta.script_name, (str(e), abortMessage))
    
    #----------------------------------------
    # If connect_result is anything but 0, then the port was not available
    #----------------------------------------
    try:
        if (int(connect_result) > 0):
            raise Exception("Either the host " + str(server) + " is not reachable or Port " + str(port) + " is not reachable on " + server, exa.meta.script_name)
    except socket.error:
        raise Exception(f"Socket connect returned: {connect_result}.", exa.meta.script_name, (str(socket.error), abortMessage))
    except Exception as e:
        raise Exception(f"Results from socket connection on host " + server + " port " + str(port) + " did not work; Return_code {}".format(connect_result), exa.meta.script_name, (str(e), abortMessage))


#######################################
# BEGIN LOGIC
#######################################
def run(ctx):
    #=======================================
    # House Keeping - Validate LDAP Host Connection 
    #========================================
    print("Hello World")
    
    if ctx.VERIFY.upper() == 'DEBUG':
        DEBUG = 1
    else:
        DEBUG = 0
    
    #----------
    # Ensure Connection String has a proper LDAP server
    #----------
    global uri
    try:
        uri = exa.get_connection(ctx.LDAP_CONNECTION).address
        ldap_server = str(uri)
    except Exception as e:
        raise Exception(f"Unable to find/parse {uri} from the exa.get_connection(ctx.LDAP_CONNECTION).address. Error caught in:", exa.meta.script_name, str(e), abortMessage)
    
    if DEBUG:
        validate_connection(ldap_server)
        
    

    #========================================
    # House Keeping - Validate remaining Connection properties
    #========================================
    try:
        user = exa.get_connection(ctx.LDAP_CONNECTION).user        #technical user for LDAP
    except Exception as e:
        raise Exception("Unable to find/parse exa.get_connection(ctx.LDAP_CONNECTION).user", exa.meta.script_name, str(e), abortMessage)
        
    try:
        password = exa.get_connection(ctx.LDAP_CONNECTION).password    #pwd of technical user
    except Exception as e:
        raise Exception("Unable to find/parse exa.get_connection(ctx.LDAP_CONNECTION).password", exa.meta.script_name, str(e), abortMessage)
        
    try:
        encoding = "utf8"  #may depend on ldap server, try latin1 or cp1252 if you get problems with special characters
    except Exception as e:
        raise Exception("Unable to set encoding = utf8", exa.meta.script_name, str(e), abortMessage)
    
    #----------------------------------------
    # Sets a network timeout of 15 seconds to connect to LDAP
    #----------------------------------------
    try:
        ldap.set_option(ldap.OPT_NETWORK_TIMEOUT, 30.0)
    except Exception as e:
	    raise Exception("Failure on ldap.set_option(ldap.OPT_NETWORK_TIMEOUT, 5.0)", exa.meta.script_name, str(e), abortMessage)
	
	#----------------------------------------
	# The below line is only needed when connecting via ldaps
	#----------------------------------------
    try:
        ldap.set_option(ldap.OPT_X_TLS_REQUIRE_CERT, ldap.OPT_X_TLS_NEVER)   # required options for SSL without cert checking
    except Exception as e:
        raise Exception("Failed! ldap.set_option(ldap.OPT_X_TLS_REQUIRE_CERT, ldap.OPT_X_TLS_NEVER", exa.meta.script_name,  str(e), abortMessage)
        
    #========================================
    # Begin LDAP interaction
    #========================================  
    try:
        ldapClient = ldap.initialize(uri)   # Connects to LDAP
    except Exception as e:
        raise Exception(f"Ldap initialization failed. Check the uri from uri = {uri}" , exa.meta.script_name, str(e), abortMessage)
    

        
#######################################
# MAIN LOGIC
#######################################

    #----------------------------------------
    # Authenticates with connection credentials
    #----------------------------------------
    try:
        ldapClient.bind_s(user, password)
    except Exception as e:
	        raise Exception(f"Failed: ldapClient.bind_s(user, password) for user {user}" , exa.meta.script_name, str(e), abortMessage)
	    
    #---------------------------------------
    # Python 3 can not handle bytes, so we decode to chg bytes to string
    #---------------------------------------  
    try:
        global results
        results = ldapClient.search_s(ctx.SEARCH_STRING.encode(encoding).decode('utf-8'), ldap.SCOPE_BASE)
    except Exception as e:
        not_found = 'No such object'
        invalid_dn = 'invalid DN'
        if not_found.find(str(e)):
            ctx.emit(ctx.SEARCH_STRING, ctx.ATTR, 'No such object')
        elif invalid_dn.find(str(e)):
            raise Exception("ldapClient.search failed: results with error={0}".format(e), exa.meta.script_name, ("Exasol ROLE with comment " + ctx.SEARCH_STRING + " is NOT found on LDAP Server."))
        else:
            raise Exception("ldapClient.search failed: results with error={0}".format(e), exa.meta.script_name, (str(e), abortMessage))
     
    #----------------------------------------
    # Prepare results for display and return results if called from Lua Script.
    # Execute the LDAP unbind regardless of outcome.
    #----------------------------------------     
    try:
        # Emits the results of the specified attributes
        for result in results:
            result_dn = result[0]
            result_attrs = result[1]
            if ctx.ATTR in result_attrs:
                [ctx.emit(ctx.SEARCH_STRING, ctx.ATTR, v.decode('utf-8')) for v in result_attrs[ctx.ATTR]]
    except Exception as e:
        not_found = 'No such object'
        if not_found.find(str(e)):
            ctx.emit(ctx.SEARCH_STRING, ctx.ATTR, 'No such object')
        else:
            raise Exception(ldap.LDAPError(e))
    finally:
        ldapClient.unbind_s()		

/

-------------------------------------------------------------------------------------
-- This script will help you explore ldap attributes. This is helpful when you do not know which attributes contain the role members or the username
-- To find out which attributes contain the group members, you can run this: select EXA_TOOLBOX.LDAP_HELPER('LDAP_SERVER', ROLE_COMMENT) from exa_Dba_roles where role_name = <role name>
-- To find out which attributes contain the username, you can run this: select EXA_TOOLBOX.LDAP_HELPER('LDAP_SERVER', user_name) from exa_dba_connections WHERE connection_name = 'LDAP_SERVER'; 
-- For other purposes, you can run the script using the LDAP connection you created and the distinguished name of the object you want to investigate: SELECT EXA_TOOLBOX.LDAP_HELPER(<LDAP connection>,<distinguished name>);
-------------------------------------------------------------------------------------
--/
--=======================================================================================================================
CREATE OR REPLACE PYTHON3 SCALAR SCRIPT "LDAP_HELPER" ("LDAP_CONNECTION" VARCHAR(2000),"SEARCH_STRING" VARCHAR(2000) UTF8) 
EMITS ("SEARCH_STRING" VARCHAR(2000) UTF8, "ATTR" VARCHAR(1000), "VAL" VARCHAR(1000) UTF8)  AS
--=======================================================================================================================
'''
###############################################
#--------- NOTES for LDAP_HELER --------------#
###############################################
-----------------------------------------------
EXECUTION_MODE options: DEBUG or EXECUTE. In debug mode, all queries are rolled back
 ----------------------------------------------

Note: This release is now PYTHON3

Purpose: This script is designed to extract LDAP information.
About:   This version of the script underwent a refactoring and was upgraded to Python3.       

What is new in this version?
--------------------------------------------
1. Added additional tests to validate the Connnection.
---------------------------------------------
  This script will end abnormally if a valid LDAP connection can not be made. Primarily,
  this will aid troubleshooting when doing a first time implentation of the LDAP Sync
  (think firewalls and forgetting to set the "LDAP Server URLS" in EXAOperation).
      This script is now more aggessive with validations and no longer passively returns
  if valid LDAP data is not extracted, unless it is intentional. We added socket
  processing to assist in validating CONNECTIONS. 
---------------------------------------------
2. Conversion to Python3 includes:
---------------------------------------------
   a. Changes in handling string and byte datatypes. There are differences between 
   Python2 and Python3. What used to work in Python2 no longer works as-is in Python3.
   b. Accounting for new error message formats in Python3.
---------------------------------------------
3. Add additional documentation
---------------------------------------------
   To improve user experience with first time implementation
   and troubleshooting.
'''


import ldap
import socket    # To test LDAP connectivity and abnormally end if LDAP server is not reachable.
                 # Basically, is the connection to the LDAP Server blocked by unknown firewall
import subprocess
            
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Script Variables
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
results = ''                # Hold LDAP results
encoding  = 'utf-8'         # Used to clarify bytes to string translation (it is a Python 3 thing)
abortMessage = ">>> Aborting with no action taken!"
server =''                  # The server extracted from the LDAP CONNECTION object
port=-1                     # Default set, which should be updated during processing
url_components = ['.',':']  # When validating the Host URL, we are looking for IP addr or www.example.com
                            #   (the "." period) or IPV6 with colons
ldap_prefix  = "://"        # The :// in ldap://
result=[]
#########################################
# FUNCTIONS
#########################################
#----------------------------------------
def extract_host(ldap_server):
#----------------------------------------

    try:
        ldap_server = str(ldap_server)          # Make ldap_serve  string object
        server = ldap_server.split(":")         # Elliminate prefix "ldap" om the conection string,Server is now a list without the ":" characters
        if len(server) > 1:
            if len(server) == 3:
                global port
                assert(isinstance(port, int))
                port = int(server[2])
            if ldap_prefix.find(server[1]):
                server = server[1].replace('//','')
    except Exception as e:
        raise Exception(f"Error, unable to parse valid values {server}, Port: {port} from LDAP Entry:", ldap_server, (str(e), abortMessage))
        
    try:
        if port < 0:
            raise ValueError("A proper port being numeric and > 0 was not provided")
        assert(port > 0)
    except Exception as e:
        raise Exception(f"Error! Port provided is < 1. We have Port {port} from LDAP Entry:", ldap_server, "The connection port read in was " + str(port), (str(e), abortMessage))
    
    return server, int(port)
#######################################
# BEGIN LOGIC
#######################################
def run(ctx):
#-------------------------------------
    #=====================================
    # Housekeeping - define and validate variables used in MAIN LOGIC section
    #=====================================
    '''
    The below information corresponds to the user needed to connect to ldap who can traverse the ldap structure and pull out user attributes. 
    1) This information should be stored in a CONNECTION object and you must GRANT ACCESS ON <CONNECTION> FOR <SCRIPT> TO <USER>
    2) More details: https://docs.exasol.com/database_concepts/udf_scripts/hide_access_keys_passwords.htm
    '''
    #----------------------------------------
    # Ensure Connection String has a proper LDAP server
    #----------------------------------------
    try:
        uri = exa.get_connection(ctx.LDAP_CONNECTION).address
        ldap_server = uri
    except Exception as e:
        raise Exception("Unable to find/parse exa.get_connection(ctx.LDAP_CONNECTION).address", exa.meta.script_name, (str(e), abortMessage))   

    server, port = extract_host(ldap_server)
    
    #----------------------------------------
    # Validate just the port extraced from the LDAP CONNECTION
    #----------------------------------------
    try:
        if isinstance(port, int) and (port > 0):
            pass
        else:
            raise Exception(f"Error, trying to validate a numeric Port NUMBER returned: {port} -- from LDAP CONNECTION entry", ldap_server)
    except Exception as e:
        raise Exception("Error, unable to extract valid values for the PORT as found in the LDAP Entry:", ldap_server, (str(e), abortMessage))
    
          
    #----------------------------------------
    # Start building a socket to then test the Host and port for reachability
    #----------------------------------------
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    except Exception as e:
        raise Exception("Unable to open socket", exa.meta.script_name, (str(e), abortMessage))
    
    #----------------------------------------
    # Set socket to timeout after 30 seconds
    #----------------------------------------
    try:
        sock.settimeout(30)
    except Exception as e:
        raise Exception("Unable to set socket timeout", exa.meta.script_name, (str(e), abortMessage))

    #----------------------------------------
    # Make socket connection to LDAP Host and port
    #----------------------------------------
    try:
        global result
        result = sock.connect_ex((server, port))
    except Exception as e:
        if result == 11:
            raise Exception("Socket timeout...unable to connect to " + str(server) + " and port " + str(port), exa.meta.script_name, (str(e), abortMessage))
        else:
            raise Exception("Can open socket, but unable to connect to " + str(server) + " and port " + str(port), exa.meta.script_name, (str(e), abortMessage))
    
    #----------------------------------------
    # If result is anything but 0, then the port was not available
    #----------------------------------------
    try:
        if int(result):
            raise Exception("Either the host " + str(server) + " is not reachable or Port " + str(port) + " is not reachable on " + server, exa.meta.script_name)
    except Exception as e:
        raise Exception("From socket connection on host " + server + " port " + str(port) + " did not work", exa.meta.script_name, (str(e), abortMessage))
        
    #========================================
    # House Keeping - Validate remaining Connection properties
    #========================================
    try:
        user = exa.get_connection(ctx.LDAP_CONNECTION).user        #technical user for LDAP
    except Exception as e:
        raise Exception("Unable to find/parse exa.get_connection(ctx.LDAP_CONNECTION).user", exa.meta.script_name, (str(e), abortMessage))
        
    try:
        password = exa.get_connection(ctx.LDAP_CONNECTION).password    #pwd of technical user
    except Exception as e:
        raise Exception("Unable to find/parse exa.get_connection(ctx.LDAP_CONNECTION).password", exa.meta.script_name,(str(e), abortMessage))
        
    try:
        encoding = 'utf-8'  #may depend on ldap server, try latin1 or cp1252 if you get problems with special characters
    except Exception as e:
        raise Exception("Unable to set encoding = utf-8", exa.meta.script_name, (str(e), abortMessage))
    
    #========================================
    # Begin LDAP interaction
    #========================================  
    try:
        ldapClient = ldap.initialize(uri)   # Connects to LDAP
    except Exception as e:
        raise Exception("Ldap initialization failed. Check the uri from uri = exa.get_connection(ctx.LDAP_CONNECTION).address #ldap/AD server" , exa.meta.script_name, (str(e), abortMessage))

    #----------------------------------------
    # Sets a timeout of 5 seconds to connect to LDAP
    #----------------------------------------
    try:
        ldapClient.set_option(ldap.OPT_NETWORK_TIMEOUT, 5.0)
    except Exception as e:
	        raise Exception("Failure on ldapClient set_option(ldap.OPT_NETWORK_TIMEOUT, 5.0)", exa.meta.script_name, (str(e), abortMessage))
        
    #----------------------------------------
	# The below line is only needed when connecting via ldaps
	#----------------------------------------
    try:
        ldapClient.set_option(ldap.OPT_X_TLS_REQUIRE_CERT, ldap.OPT_X_TLS_NEVER)   # required options for SSL without cert checking
    except Exception as e:
        raise Exception("Failed! ldapClient.set_option(ldap.OPT_X_TLS_REQUIRE_CERT, ldap.OPT_X_TLS_NEVER", exa.meta.script_name,  (str(e), abortMessage))
        
#######################################
# MAIN LOGIC
#######################################

    #----------------------------------------
    # Authenticates with connection credentials
    #----------------------------------------
    try:
        ldapClient.bind_s(user, password)
    except Exception as e:
	    raise Exception(f"Failed: ldapClient.bind_s(user, password) for user {user}" , exa.meta.script_name, (str(e), abortMessage))
	    
	#---------------------------------------
    # Python 3 can not handle bytes, so we decode to chg bytes to string
    #---------------------------------------  
    try:
        global results
        results = ldapClient.search_s(str(ctx.SEARCH_STRING.encode(encoding).decode('utf-8')), ldap.SCOPE_BASE)
    except Exception as e:
        not_found = 'No such object'
        if not_found.find(str(e)):
            ctx.emit(ctx.SEARCH_STRING, 'CN not found', 'No such object')
        else:
            raise Exception("ldapClient.search failed: results with error={0}".format(e), exa.meta.script_name, (str(e), abortMessage))
        
    #----------------------------------------
    # Prepare results for display and return results if called from Lua Script.
    # Execute the LDAP unbind regardless of outcome.
    #----------------------------------------
    try:
        for result in results:     # Emits the results of the specified attributes
            result_dn    = result[0]
            result_attrs = result[1]
            for attrs in result_attrs:
                for y in result_attrs[attrs]:
                    y = str(bytes(y).decode('utf-8'))
                    ctx.emit(result_dn, attrs, str(y))
    except Exception as e:
        print(e)
        not_found = 'No such object'
        if not_found.find(str(e)):
            ctx.emit(ctx.SEARCH_STRING, 'DN not found', 'No such object')
        else:
            raise Exception(ldap.LDAPError(e))
    finally:
        ldapClient.unbind_s()		     

/


-- This script will perform the synchronizations
--/
--====================================
CREATE OR REPLACE LUA SCRIPT "SYNC_AD_GROUPS_TO_DB_ROLES_AND_USERS" (LDAP_CONNECTION, GROUP_ATTRIBUTE, USER_ATTRIBUTE, EXECUTION_MODE, OPT_SEND_EMAIL, OPT_WRITE_AUDIT) RETURNS TABLE AS
--====================================
/*--------------------------------------
-- NOTES for Usage
---------------------------------------
-- GROUP ATTRIBUTE refers to the attribute to search in the group for all of the members. Default is 'member'
-- USER ATTRIBUTE refers to the attribute of the user which contains the username. Default is uid
-- EXECUTION_MODE options: DEBUG or EXECUTE. In debug mode, all queries are rolled back

*/
--###################################
-- FUNCTIONS (Enhancements)
--###################################
---------------------------------------
function audit_log() 
---------------------------------------
--
-- This function only gets executed if parameter "OPT_WRITE_AUDIT" is set to 'ON'.
--
    local user = exa.meta.current_user
    local session = exa.meta.session_id
    local schema  = exa.meta.current_schema
    local script  = exa.meta.script_name
    local start_time = os.date('%Y-%m-%d %H:%M:%S')
    ------------------------------
    -- If Debug and EXAOperation does not set the "LDAP Server URL" parameter filled out, 
    --   then don't write the first record to the LDAP_REPORT_TBL, 
    --   as it was only informational and not pertinent to LDAP changes. Do display "LDAP Server URL" 
    --   is not set message in the returned record output. 
    --       If "DEBUG MODE ON" and OPT_WRITE_AUDIT parameter is 'ON',then writing to the LDAP_REPORT_TBL
    --   will populate the column "MODE" with "DEBUG". This allows querying LDAP_REPORT_TBL 
    --   for "DEBUG" or "EXECUTE".
    ------------------------------
    if (debug) then
        ------------------------------
        -- This "if" asks if the EXAOperation LDAP parameter is set.
        -- If it's not set, then the returned results includes a 
        -- message stating EXAOperation's "LDAP Server URL" is NOT set". We do NOT
        -- write this LDAP message to the LDAP_RESULT_TBL.
        ------------------------------
        if (res_meta[1][1] == null) then 
            for i=2,#summary do
               local suc1, res1 = pquery([[INSERT INTO "LDAP_REPORT_TBL" values(:o,:ses,:order, :uzr,:sch, :scr, :mo, :s, :suc, :err)]],{o=start_time, ses=session, order = i-1, uzr=user, sch=schema, scr=script, mo=string.upper(EXECUTION_MODE), s=summary[i][1], suc=summary[i][2], err=summary[i][3]})
               if not suc1 then
                   output(res1.error_message)
               end -- END if
            end -- END for
        else
        ------------------------------
        -- If the EXAOperation "LDAP: parameter is set, there is no message
        -- to skip when writing to the LDAP_REPORT_TBL
        ------------------------------
           for i=1,#summary do
               local suc1, res1 = pquery([[INSERT INTO "LDAP_REPORT_TBL" values(:o,:ses,:order, :uzr,:sch, :scr, :mo, :s, :suc, :err)]],{o=start_time, ses=session, order = i, uzr=user, sch=schema, scr=script, mo=string.upper(EXECUTION_MODE), s=summary[i][1], suc=summary[i][2], err=summary[i][3]})
               if not suc1 then
                   output(res1.error_message)
               end -- END if
            end -- END for      
        end --END if res_meta
    else
        ------------------------------
        -- This is the ELSE that writes the actual changes,
        -- that is, the parameter "EXECUTION_MODE" is set to "EXECUTE".
        ------------------------------
        for i=1,#summary do
           local suc1, res1 = pquery([[INSERT INTO "LDAP_REPORT_TBL" values(:o,:ses,:order, :uzr,:sch, :scr, :mo, :s, :suc, :err)]],{o=start_time, ses=session, order = i, uzr=user, sch=schema, scr=script, mo=string.upper(EXECUTION_MODE), s=summary[i][1],  suc=summary[i][2], err=summary[i][3]})
           if not suc1 then
               output(res1.error_message)
           end -- END if
        end -- END for loop
    end -- END if (debug)
end --END Function

---------------------------------------
function email_ldap(summary) 
---------------------------------------
--
-- This function only gets executed if parameter "OPT_SEND_MAIL" is set to 'ON'.
--
    local s = {}
    for i=1,#summary do
        s[#s+1] = "'"
        s[#s+1] = summary[i][1]
        s[#s+1] = "'"
    end
    s = table.concat(s)
    -- output(s) --Uncomment to see output (providing the EXECUTE SCRIPT SQL command
    --      has the "OUTPUT" option)

    local schema  = exa.meta.current_schema
    --
    -- Search for script MAIL_MAN in the database
    --
    suc_sch, res_sch = pquery([[SELECT COUNT(*) FROM EXA_DBA_SCRIPTS WHERE SCRIPT_SCHEMA = :scm and SCRIPT_NAME = 'MAIL_MAN']],{scm=schema})
    
    --
    -- If MAIL_MAN is found, then continue, else OUTPUT the script is not in the database
    --     This prevents accidental error of calling a non-existent script
    --
    if suc_sch then
        if res_sch[1][1] == 1 then
            --
            -- MAIL_MAN script found in database, so "make the call to MAIL_MAN"
            --
            sucy, resy = pquery([[select MAIL_MAN(:str)]], {str=s})
            if sucy ~= true then
                 output(resy.error_message)
            end -- END if stmt
        else
            output("Send email not executed. Could not find script = MAIL_MAN under schema "..schema)
        end -- END res_sch
    else
        output("Send email not executed. Could not find script = MAIL_MAN under schema "..schema)
    end -- END suc_sch
end

--###################################
-- BEGIN MAIN LOGIC
--###################################
-------------------------------------
-- Enhancement
-------------------------------------
if OPT_WRITE_AUDIT == 'ON' or string.upper(EXECUTION_MODE) == 'EXECUTE' then 
    query([[CREATE TABLE IF NOT EXISTS LDAP_REPORT_TBL(START_TIME Timestamp, SESSION_ID CHAR(19), REC_NO INTEGER, USER_ID VARCHAR(200), SCHEMA_NAME VARCHAR(200), SCRIPT_NAME VARCHAR(200), MODE CHAR(7), QUERY VARCHAR(1000), SUCCESS BOOLEAN, ERROR VARCHAR(1000))]])
    query([[commit]])  
end
-------------------------------------
-- End of enhancement
-------------------------------------

if GROUP_ATTRIBUTE == NULL then
        GROUP_ATTRIBUTE = 'member'
end

if USER_ATTRIBUTE == NULL then
        USER_ATTRIBUTE = 'uid'
end

if EXECUTION_MODE == NULL then
        debug = false
elseif string.upper(EXECUTION_MODE) == 'EXECUTE' then
        debug = false
elseif string.upper(EXECUTION_MODE) == 'DEBUG' then
        debug = true
else
        error([[Invalid entry for EXECUTION_MODE. Please use 'DEBUG' or 'EXECUTE']])
end


dcl = query([[

WITH 
---------------------------------------
get_ad_group_members AS (
---------------------------------------
/* This CTE will get the list of members in LDAP for each role that contains a comment */

		/*snapshot execution*/ SELECT  
		EXA_TOOLBOX.GET_AD_ATTRIBUTE(:l, ROLE_COMMENT, 'uniqueMember',:em)
		FROM
		select * from EXA_DBA_ROLES
		where ROLE_NAME NOT IN ('PUBLIC','DBA') AND UPPER(ROLE_COMMENT) LIKE '%DC=%'
		--exclude default EXASOL groups, all other roles MUST be mapped to AD/LDAP groups
		--the mapping to a LDAP role is done via a COMMENT 
	)
---------------------------------------
, exa_membership as (
---------------------------------------
/* This CTE gets the list of users who are members of roles from Exasol. This is used to compare the groups between LDAP and EXA */

        /*snapshot execution*/ SELECT R.ROLE_COMMENT, U.DISTINGUISHED_NAME, P.GRANTED_ROLE, P.GRANTEE FROM EXA_DBA_ROLE_PRIVS P
                JOIN EXA_DBA_ROLES R ON R.ROLE_NAME = P.GRANTED_ROLE
                JOIN EXA_DBA_USERS U ON U.USER_NAME = P.GRANTEE
                WHERE UPPER(R.ROLE_COMMENT) LIKE '%DC=%'
                AND UPPER(U.DISTINGUISHED_NAME) LIKE '%DC=%'
                AND GRANTED_ROLE NOT IN ('PUBLIC')
        )
---------------------------------------
, alter_users as (
---------------------------------------
/* This CTE will find all users who do not have a DISTINGUISHED_NAME configured in Exasol, but DOES have a matching username.
   In these cases, the script will ALTER the user and change the distinguished name instead of re-creating the user */

        /*snapshot execution*/ SELECT 'ALTER USER "' || upper(VAL) || '" IDENTIFIED AT LDAP AS ''' || SEARCH_STRING || ''';' AS DCL_STATEMENT, 1 ORDER_ID, UPPER(val) VAL, search_string
        FROM (
                select EXA_TOOLBOX.GET_AD_ATTRIBUTE(:l, VAL, 'uid', :em) from
			(
				select distinct VAL
				from	
				get_ad_group_members 
				WHERE 
				VAL NOT IN 
				(
					SELECT distinct  DISTINGUISHED_NAME 
					FROM
		 			EXA_DBA_USERS
				)
				and VAL NOT like '%No such object%'
			)  --get uid attribute as USER_NAME in database
		
		) WHERE upper(VAL) IN (SELECT DISTINCT USER_NAME FROM EXA_DBA_USERS))
---------------------------------------
, drop_users AS (
---------------------------------------
/* This CTE will find all users who are no longer a part of any LDAP group and will drop them
    NOTE: If the user is the owner of any database objects, the DROP will fail and an appropriate error message is displayed in the script output
    If you want to drop users who are owners, you can amend the query and replace '"; --' with '" CASCADE; -- */
    
		/*snapshot execution*/ select
		'DROP USER "' || UPPER(USER_NAME) || '"; --' || DISTINGUISHED_NAME  AS DCL_STATEMENT, 5 ORDER_ID
		from
		EXA_DBA_USERS
		WHERE UPPER(DISTINGUISHED_NAME) LIKE '%DC=%'
		AND
		DISTINGUISHED_NAME NOT IN 
		(
			SELECT distinct VAL
			FROM
 			get_ad_group_members 
		)
		AND UPPER(USER_NAME) NOT IN (SELECT VAL FROM ALTER_USERS)
	)
---------------------------------------
, create_users AS (
---------------------------------------
/* This CTE will create users who are found to be in an LDAP group, but the distinguished name is not found in Exasol
    Users who are altered are ignored and not created again */
    
		/*snapshot execution*/ select
		'CREATE USER "' ||  UPPER(VAL)  || '"  IDENTIFIED AT LDAP AS ''' || SEARCH_STRING ||''';'  AS DCL_STATEMENT,2 ORDER_ID
		from

		(
			select EXA_TOOLBOX.GET_AD_ATTRIBUTE(:l, VAL, 'uid', :em) from
			(
				select distinct VAL
				from	
				get_ad_group_members 
				WHERE 
				VAL NOT IN 
				(
					SELECT distinct  DISTINGUISHED_NAME 
					FROM
		 			EXA_DBA_USERS
				) and VAL NOT like '%No such object%'
			)  --get uid attribute as USER_NAME in database
		
		)
		where UPPER(VAL) NOT IN (SELECT VAL FROM ALTER_USERS)

	)
---------------------------------------
,revokes AS (
---------------------------------------
/* This CTE will only revoke roles from users if they are a part a member of the role in EXA, but are no longer in the group in LDAP */

		SELECT 'REVOKE "' || GRANTED_ROLE || '" FROM "' || UPPER(GRANTEE) || '";' AS DCL_STATEMENT, 3 ORDER_ID from exa_membership e
                full outer join get_ad_group_members a on e.role_comment = a.search_string and e.distinguished_name = a.val
                where search_string is null
	)
---------------------------------------
,all_user_names(DISTINGUISHED_NAME, VAL, USER_NAME)  as (
---------------------------------------
/* This CTE will get the "user name" attribute for LDAP. The exact attribute may vary */
	
	select EXA_TOOLBOX.GET_AD_ATTRIBUTE(:l, VAL, 'uid', :em) from
	(
		select distinct VAL
		from	
		get_ad_group_members
		WHERE VAL NOT like '%No such object%'
	)

)
---------------------------------------
, grants AS (
---------------------------------------
/* This CTE will grant roles to users when it sees an LDAP user who is a role member, but the equivalent database user is not granted the role */
        
        /*snapshot execution*/ SELECT 'GRANT "' || R.ROLE_NAME ||'" TO "' || UPPER(U.USER_NAME) || '";' AS DCL_STATEMENT, 4 ORDER_ID FROM EXA_MEMBERSHIP e
		FULL OUTER JOIN get_ad_group_members a on e.role_comment = a.search_string and e.distinguished_name = a.val
		full outer join 
		      (SELECT ROLE_NAME, ROLE_COMMENT FROM EXA_DBA_ROLES where ROLE_NAME NOT IN ('PUBLIC','DBA') AND UPPER(ROLE_COMMENT) LIKE '%DC=%') r
		      on r.role_comment = a.search_string 
		JOIN ALL_USER_NAMES u on u.distinguished_name = a.val
		where e.role_comment is null
		and  u.USER_NAME NOT like '%No such object%'
		
	)

select DCL_STATEMENT, ORDER_ID from alter_users

union all

select * from  create_users

union all

select * from revokes

union all

select * from grants

union all

select * from drop_users

order by ORDER_ID ;

]], {l=LDAP_CONNECTION, u=USER_ATTRIBUTE, g=GROUP_ATTRIBUTE,em=EXECUTION_MODE})

---------------------------------------
-- Debug information showing the EXAOperation UI parameter "LDAP Server URL" address.
---------------------------------------
suc_meta, res_meta = pquery([[select Param_value from EXA_COMMANDLINE   where upper(Param_name) = :ln]], {ln='LDAPSERVER'})

summary = {}

if (debug) then
-- in debug mode, all queries are performed to see what an error message may be, but are then rolled back so no changes are committed.
       ----------------------------------------
       --Notify user if EXAOperation missing LDAP connection
       ----------------------------------------
        if (suc_meta) then
            if (res_meta[1][1] == null) then
                summary[#summary+1] = {'--WARNING! EXASolution (EXAOperation) "LDAP Server URLs" parameter is NOT set. Exasol can not auth using LDAP', null,null}
            end -- End if (res_meta...
        end -- End If suc_meta
        
        ----------------------------------------
        -- Start the LDAP messages stating DEBUG
        ----------------------------------------
        
        summary[#summary+1] = {"DEBUG MODE ON - ALL QUERIES ROLLED BACK",null,null}
        
        for i=1,#dcl do
                my_DCL_STATEMENT = string.gsub( dcl[i].DCL_STATEMENT, "(CREATE USER.+%a)(')(%a)", "%1%2%2%3", 1)
                --output(my_DCL_STATEMENT)
                suc,res = pquery(my_DCL_STATEMENT)
                            
                if (suc) then
                -- query was successful
                        summary[#summary+1] = {my_DCL_STATEMENT,'TRUE',NULL}
                else
                -- query returned an error message, display the error in the script output
                        summary[#summary+1] = {my_DCL_STATEMENT,'FALSE',res.error_message}
                end
        end 
        query([[ROLLBACK]])
else
-- Not debug mode, queries can be committed on script completion
        for i=1,#dcl do
            my_DCL_STATEMENT = string.gsub( dcl[i].DCL_STATEMENT, "(CREATE USER.+%a)(')(%a)", "%1%2%2%3", 1)
                suc,res = pquery(my_DCL_STATEMENT)
                
                if (suc) then
                --query was successful
                        summary[#summary+1] = {my_DCL_STATEMENT,'TRUE',NULL}
                else
                --query returned an error message, display the error in the script output
                        summary[#summary+1] = {my_DCL_STATEMENT,'FALSE',res.error_message}
                end  
        end
end


---------------------------------------
-- Enhancement
---------------------------------------
if OPT_SEND_EMAIL == 'ON' then
    email_ldap(summary)
end

-------------------------------------
-- Enhancement 
-------------------------------------
if OPT_WRITE_AUDIT == 'ON' or string.upper(EXECUTION_MODE) == 'EXECUTE' then
    audit_log()
end

return summary, ("QUERY_TEXT VARCHAR(200000),SUCCESS BOOLEAN, ERROR_MESSAGE VARCHAR(20000)")
/


'''
This script, named "MAIL_MAN", is optional. To make fit for use, some changes on your end are needed.
You only need this script if you are setting the SYNC_AD_GROUPS_TO_DB_ROLES_AND_USER parameter "OPT_SEND_EMAIL"
to "ON".
'''

--/
--========================================================================================================
CREATE OR REPLACE PYTHON SCALAR SCRIPT MAIL_MAN (summary varchar(200000)) emits (message varchar(1000)) AS
--========================================================================================================
import smtplib
from email.mime.text import MIMEText
import datetime as dt
#######################################
# FUNCTIONS
#######################################
#---------------------------------------
def get_timestamp():
#---------------------------------------
    now = dt.datetime.now()
    now_formatted = now.strftime("%Y-%m-%d %H.%M")
    return now_formatted

#---------------------------------------
def parse_summary(summaries):
#---------------------------------------
    s = ''
    cr = "\n"
    for sum in summaries:
        #ctx.emit(sum)
        s +=sum
        s +=cr
    return s

#######################################
# MAIN LOGIC
#######################################

#---------------------------------------
def run(ctx):
#---------------------------------------
    summaries = ctx.summary.split("'")
    summaries = [sum.strip(",") for sum in summaries if sum != ' ']
    s = parse_summary(summaries)
    print(s)
    
    date_now = get_timestamp()
    #-----------------------------------
    # Begin example mail code.
    # Be sure and add the variable "s" to the body.
    # This has been done for you, see the line: "body +=s"
    #-----------------------------------
    # Mail server credentials
    #-----------------------------------
    mail_user = 'yourmailuser@example.com'
    mail_password = 'yourmailpassword'
    #-----------------------------------
    # Mail content
    #-----------------------------------
    sent_from = 'jane.doe@example.com'
    to = ['exa-john@exasol.com']
    subject = 'LDAP Sync Report'
    body = "Reporting for {}\n".format(get_timestamp())
    body += s

    email_text = """From: %s\nTo: %s\nSubject: %s\n\n%s""" % (sent_from, ", ".join(to), subject, body)
    try:
        server = smtplib.SMTP_SSL('smtp.example.com', 465)
        server.ehlo()
        server.login(mail_user, mail_password)
        server.sendmail(sent_from, to, email_text)
        server.close()
        print 'Email sent!'
    except:
        ctx.emit('Something is not working')
/



