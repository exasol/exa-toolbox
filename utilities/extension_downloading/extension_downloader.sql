/*

    This script uploads a GitHub release to the selected bucket.

*/

CREATE SCHEMA IF NOT EXISTS EXA_toolbox;

CREATE OR REPLACE CONNECTION BUCKET_CONNECTION
      TO 'http://<host>:<port>/<bucket name>'
      USER 'w'
      IDENTIFIED BY '<writing password>';

-- Example:
-- CREATE OR REPLACE CONNECTION BUCKET_CONNECTION TO 'http://localhost:2580/test' USER 'w' IDENTIFIED BY 'password';

--/
CREATE OR REPLACE PYTHON SET SCRIPT EXA_toolbox.upload_to_bucket_with_link(file_to_download_name VARCHAR(1000), github_user VARCHAR(1000), repository_name VARCHAR(1000), release_name VARCHAR(1000))
EMITS (outputs VARCHAR(20000)) AS
import requests
import sys

def download_python_file(file_name):
        python_code_github_link = "https://raw.githubusercontent.com/exasol/exa-toolbox/master/utilities/extension_downloading/"
        r = requests.get(python_code_github_link + file_name, allow_redirects=True)
        with open('/tmp/' + file_name, 'wb') as f:
                f.write(r.content)

def run(ctx):
        download_python_file('ContainerFileUploader.py')
        download_python_file('ReleaseLinkExtractor.py')
        sys.path.append('/tmp')

        from ContainerFileUploader import ContainerFileUploader
        file_uploader = ContainerFileUploader(ctx.file_to_download_name, ctx.github_user, ctx.repository_name, ctx.release_name)

        bucket_connection_string = exa.get_connection("BUCKET_CONNECTION")
        file_uploader.upload(bucket_connection_string.address, bucket_connection_string.user, bucket_connection_string.password)
/

-- How to run the script:
-- SELECT upload_to_bucket_with_link('<name of the file to upload from github>', '<name of the user holding the repository>', '<name of the repository>', '<name of the release>');

-- Example:
-- SELECT upload_to_bucket_with_link('python3-ds-EXASOL-6.1.0', 'exasol', 'script-languages', 'latest');

-- EOF