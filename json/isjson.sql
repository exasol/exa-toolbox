/*

    This UDF tests whether a string contains valid JSON document.

*/

CREATE SCHEMA IF NOT EXISTS EXA_toolbox;

--/
CREATE OR REPLACE PYTHON SCALAR SCRIPT EXA_toolbox.isjson(json VARCHAR(2000000)) RETURNS BOOLEAN AS
import json

def run(ctx):
    if ctx[0] == None:
        return None
    try:
        j = json.loads(ctx[0])
    except:
        return False
    return True
/

-- Examples
-- SELECT isjson('{"id":1,"first_name":"Mark","last_name":"Trenaman","info":{"phone":"573-411-0171","city":"Washington", "hobbies":["sport", "music", "reading"]}}');
-- SELECT isjson('Just a simple string');
-- SELECT isjson(NULL);

-- EOF
