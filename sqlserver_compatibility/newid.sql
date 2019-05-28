/*

    This function is a compatibility implementation of MS SQL Server's NEWID function.
    It returns a version 4 UUID/GUID (a uniqueidentifier equivalent). (https://en.wikipedia.org/wiki/Universally_unique_identifier#Version_4_(random))
    Note: As Exasol does not currently support UUID/GUID data type, CHAR(36) can be to store such values.

*/

CREATE SCHEMA IF NOT EXISTS EXA_toolbox;

--/
CREATE OR REPLACE PYTHON SCALAR SCRIPT EXA_toolbox.newid() RETURNS CHAR(36) AS
import uuid

def run(ctx):
    return str(uuid.uuid4())
/

-- Example:
-- SELECT newid();

-- EOF
