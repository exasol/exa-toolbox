/*

    This script uploads a GitHub release to the selected bucket.

*/


CREATE SCHEMA IF NOT EXISTS EXA_toolbox;

--/
CREATE OR REPLACE PYTHON SET SCRIPT EXA_toolbox.upload_to_bucket_with_link(file_to_download_name VARCHAR(1000), github_user VARCHAR(1000), repository_name VARCHAR(1000), release_name VARCHAR(1000), upload_url VARCHAR(1000))
EMITS (outputs VARCHAR(20000)) AS
import requests

def run(ctx):
        python_code_github_link = "https://raw.githubusercontent.com/exasol/exa-toolbox/master/utilities/extension_downloading/"
        r = requests.get(python_code_github_link + 'ContainerFileUploader.py', allow_redirects=True)
        with open('/tmp/ContainerFileUploader.py', 'wb') as f:
                f.write(r.content)

        r2 = requests.get(python_code_github_link + 'ReleaseLinkExtractor.py', allow_redirects=True)
        with open('/tmp/ReleaseLinkExtractor.py', 'wb') as f2:
                f2.write(r2.content)

        import sys
        sys.path.append('/tmp')

        from ContainerFileUploader import ContainerFileUploader
        file_uploader = ContainerFileUploader(ctx.file_to_download_name, ctx.github_user, ctx.repository_name, ctx.release_name)
        file_uploader.upload(ctx.upload_url)
/

-- How to run the script:
-- SELECT upload_to_bucket_with_link('<name of the file to upload from github>', '<name of the user holding the repository>', '<name of the repository>', <name of the release>, '<bucket address for uploading>');

-- Example:
-- SELECT upload_to_bucket_with_link('python3-ds-EXASOL-6.1.0', 'exasol', 'script-languages', 'latest', 'http://w:writepassword@localhost:2580/test/test.tar.gz');

-- EOF