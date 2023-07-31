import xmlrpc.client
import urllib3, ssl
import json

# Disable SSL warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Add the IP Address of the database access node (beginning with version 8) or a data node
database_host = '108.129.27.78'

# Add the port which is running ConfD. By default it is 443 in version 7.1 and 20003 in version 8. Make sure that this port is open.

port = 20003

# Enter the administrative username you are connecting with (not a database username)
user = 'admin'

# Enter the password for that user
pw = 'exasol'

connection_string = f'https://{user}:{pw}@{database_host}:{port}'

sslcontext = ssl._create_unverified_context()

# Establish connection
conn = xmlrpc.client.ServerProxy(connection_string, context=sslcontext, allow_none=True)

# View the list of all available confd jobs
# The list is also available in our documentation
all_jobs = conn.job_list()
for k in all_jobs:
    print(k)

# Set which job you want to run
job_name = 'db_state'

# View the required parameters for a given job
# This information is also available in our documentation
job_details = conn.job_desc(job_name)[1]

for i, k in enumerate(job_details):
    if i == 0:
        print("====================Job Description===============\n")
    elif i == 1:
        print("\n==================Mandatory Parameters==========\n")
    elif i == 2:
        print("\n==================Optional Parameters===========\n")
    elif i == 3:
        print("\n==================Substitute Parameters=========\n")
    elif i == 4:
        print("\n==================Allowed Users=================\n")
    elif i == 5:
        print("\n==================Allowed Groups================\n")
    elif i == 6:
        print("\n==================Examples=======================\n")
    else:
        break

    print(json.dumps(k, indent=4))

# Set the parameters for the chosen job
params = {'db_name': 'Exasol'}

# Execute a job immediately and waits for it to finish and returns the result
conn.job_exec(job_name, {'params': params})

# =============================================================================
# The next commands show alternative ways to interact with confd

# Starts the given job and parameters.
# Returns the job ID.
job_id = conn.job_start(job_name, {'params': params})

# Waits for the given job to be finished.
# Returns True if the job finishes before the given timeout in seconds, False otherwise.
# Please be noted: timeout can be overridden if there is such a argument in job's parameter list (as in the example and section 'Job List').
timeout = 5
if conn.job_wait(job_id, {'timeout': timeout}):

    # Get all details about the job once the job is finished
    print(conn.job_info({'job_id': job_id}))

    if conn.job_result(job_id)['result_code'] == 0:  # checks if the job was successful
        # prints the results of the job since the job was successful
        print(conn.job_result(job_id)['result_output'])
    else:
        # prints the error message
        print(conn.job_result(job_id)['result_desc'])

# Alternatively to job_wait, you can use job_finished which only checks if the job with the specified ID is finished
conn.job_finished(job_id)
