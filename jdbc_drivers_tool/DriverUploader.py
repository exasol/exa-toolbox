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
    parser.add_argument('--bucketfsUrl', help='Url to connect to Exasol.')
    parser.add_argument('--pathToDriver', help="Path to the driver'folder.")
    parser.add_argument('--driverName', help='Name of the driver in the EXAoperations.')
    parser.add_argument('--driverMainClass', help="Main class of the driver.")
    parser.add_argument('--driverPrefix', help='Connection string prefix.')
    args = parser.parse_args()

    create_jdbc_driver_with_all_jars(args.bucketfsUrl, args.pathToDriver, args.driverName, args.driverMainClass,
                                     args.driverPrefix)
if __name__== "__main__":
    main()

# How to use:

# Download this file [1] and run the following command in a terminal:
# python DriverUploading.py --bucketfsUrl 'https://<read password>:<write password>@<host>:<port>/<cluster>/' --pathToDriver '/path/to/the/driver/folder/' --driverName '<driver name>' --driverMainClass '<driver main class>' --driverPrefix '<driver prefix>:'
# [1]: https://raw.githubusercontent.com/exasol/exa-toolbox/master/jdbc_drivers_tool/DriverUploader.py

# For example:
# python DriverUploading.py --bucketfsUrl 'https://pass:pass@localhost:4433/cluster1/' --pathToDriver '/home/jdbc drivers/SimbaJDBCDriverforGoogleBigQuery42_1.2.0.1000/' --driverName 'bigquery' --driverMainClass 'com.simba.googlebigquery.jdbc42.Driver' --driverPrefix 'jdbc:bigquery:'
