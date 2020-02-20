import glob
import os
import ssl
from getpass import getpass
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
    parser.add_argument('--username', help='A username to login into EXAoperations.')
    parser.add_argument('--hostPortAndCluster', help='An url to connect to Exasol in format <host>:<port>/<cluster>/.')
    parser.add_argument('--pathToDriver', help="A path to the driver'folder.")
    parser.add_argument('--driverName', help='A name of the driver in the EXAoperations.')
    parser.add_argument('--driverMainClass', help="A main class of the driver.")
    parser.add_argument('--driverPrefix', help='A connection string prefix.')
    args = parser.parse_args()

    username = args.username
    password = None
    host_port_and_cluster = args.hostPortAndCluster
    path_to_driver = args.pathToDriver
    driver_name = args.driverName
    driver_main_class = args.driverMainClass
    driver_prefix = args.driverPrefix

    if password is None:
        password = getpass()
    url = 'https://{username}:{password}@{host_port_and_cluster}'.format(username=username,
                                                                         password=password,
                                                                         host_port_and_cluster=host_port_and_cluster)
    create_jdbc_driver_with_all_jars(url, path_to_driver, driver_name, driver_main_class, driver_prefix)


if __name__ == "__main__":
    main()

# How to use:

# 1. Download this file [1]
# 2. Run the following command in a terminal:
#  python DriverUploading.py --username '<username>' --hostPortAndCluster '<host>:<port>/<cluster>/' --pathToDriver '/path/to/the/driver/folder/' --driverName '<driver name>' --driverMainClass '<driver main class>' --driverPrefix '<driver prefix>:'
# 3. Input an EXAoperations password.

# [1]: https://raw.githubusercontent.com/exasol/exa-toolbox/master/jdbc_drivers_tool/DriverUploader.py

# For example:
# python DriverUploading.py  --username 'user' --hostPortAndCluster 'localhost:4433/cluster1/' --pathToDriver '/home/jdbc drivers/SimbaJDBCDriverforGoogleBigQuery42_1.2.0.1000/' --driverName 'bigquery' --driverMainClass 'com.simba.googlebigquery.jdbc42.Driver' --driverPrefix 'jdbc:bigquery:'
