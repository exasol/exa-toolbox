/*

    This script uploads a GitHub release to the selected bucket.

*/


CREATE SCHEMA IF NOT EXISTS EXA_toolbox;

--/
CREATE OR REPLACE PYTHON3 SET SCRIPT EXA_toolbox.upload_to_bucket_with_link(script_holder_schema_name VARCHAR(1000), release_name VARCHAR(1000), git_hub_api_link VARCHAR(2000), upload_url VARCHAR(1000)) EMITS (outputs VARCHAR(2000000)) AS
import requests

def run(ctx):
        r = requests.get('https://raw.githubusercontent.com/AnastasiiaSergienko/exa-toolbox/extension_downloader/utilities/extension_downloading/ContainerFileUploader.py', allow_redirects=True)
        with open('/tmp/ContainerFileUploader.py', 'wb') as f:
                f.write(r.content)

        r2 = requests.get('https://raw.githubusercontent.com/AnastasiiaSergienko/exa-toolbox/extension_downloader/utilities/extension_downloading/ReleaseLinkExtractor.py', allow_redirects=True)
        with open('/tmp/ReleaseLinkExtractor.py', 'wb') as f2:
                f2.write(r2.content)

        import sys
        sys.path.append('/tmp')

        from ContainerFileUploader import ContainerFileUploader
        file_uploader = ContainerFileUploader(ctx.script_holder_schema_name, ctx.release_name, ctx.git_hub_api_link)
        file_uploader.upload(ctx.upload_url)
/

-- How to run the script:
-- SELECT upload_to_bucket_with_link('<name of the file to upload from github>', '<link to the github api>', '<bucket address for uploading>');

-- Example:
-- SELECT upload_to_bucket_with_link('python3-ds-EXASOL-6.1.0', 'https://api.github.com/repos/exasol/script-languages/releases/latest', 'http://w:writepassword@localhost:2580/test/test.tar.gz');

-- EOF