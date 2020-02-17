import glob
import os
import ssl
import sys
from xmlrpc.client import Binary, Server


def create_jdbc_driver_with_all_jars(server_proxy: str, path_to_the_jars_folder: str,
                                     jdbc_name: str, jdbc_main_class: str, jdbc_prefix: str):
    srv = Server(server_proxy, context=ssl._create_unverified_context())
    jdbc_name = srv.addJDBCDriver(
        {'comment': '', 'jdbc_main': jdbc_main_class, 'jdbc_name': jdbc_name, 'jdbc_prefix': jdbc_prefix})
    jdbc = getattr(srv, jdbc_name)
    for filename in glob.glob(os.path.join(path_to_the_jars_folder, '*.jar')):
        jar = open(filename, "rb")
        read = jar.read()
        jdbc.uploadFile(Binary(read), os.path.basename(filename))
    print("Uploaded successfully.")


server_proxy = sys.argv[1]
path_to_the_jars_folder = sys.argv[2]
jdbc_name = sys.argv[3]
jdbc_main_class = sys.argv[4]
jdbc_prefix = sys.argv[5]

create_jdbc_driver_with_all_jars(server_proxy, path_to_the_jars_folder, jdbc_name, jdbc_main_class, jdbc_prefix)

# How to use:

# Download this file and run the following command in a terminal:
# python DriverUploading.py 'https://<read password>:<write password>@<host>:<port>/<cluster>/' '/path/to/the/driver/folder/' '<driver name>' '<driver main class> '<driver prefix>:'

# For example:
# python DriverUploading.py 'https://pass:pass@localhost:4433/cluster1/' '/home/jdbc drivers/SimbaJDBCDriverforGoogleBigQuery42_1.2.0.1000/' 'bigquery' 'com.simba.googlebigquery.jdbc42.Driver' 'jdbc:bigquery:'
