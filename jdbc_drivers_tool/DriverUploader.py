import glob
import os
import ssl
from xmlrpc.client import Binary, Server
import argparse


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

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('arguments', type=str, nargs=5)
    args = parser.parse_args().arguments

    create_jdbc_driver_with_all_jars(args[0], args[1], args[2], args[3], args[4])

if __name__== "__main__":
    main()

# How to use:

# Download this file [1] and run the following command in a terminal:
# python DriverUploading.py 'https://<read password>:<write password>@<host>:<port>/<cluster>/' '/path/to/the/driver/folder/' '<driver name>' '<driver main class> '<driver prefix>:'
# [1]: https://raw.githubusercontent.com/exasol/exa-toolbox/master/jdbc_drivers_tool/DriverUploader.py

# For example:
# python DriverUploading.py 'https://pass:pass@localhost:4433/cluster1/' '/home/jdbc drivers/SimbaJDBCDriverforGoogleBigQuery42_1.2.0.1000/' 'bigquery' 'com.simba.googlebigquery.jdbc42.Driver' 'jdbc:bigquery:'
