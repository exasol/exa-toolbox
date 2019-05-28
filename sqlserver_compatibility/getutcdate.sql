/*

    This function is a compatibility implementation of MS SQL Server's GETUTCDATE function.
    It returns the current database system timestamp in the UTC (Coordinated Universal Time) time zone.

*/

CREATE SCHEMA IF NOT EXISTS EXA_toolbox;

--/
CREATE OR REPLACE FUNCTION EXA_toolbox.getutcdate() RETURN TIMESTAMP IS
BEGIN
    RETURN CONVERT_TZ(SYSTIMESTAMP, DBTIMEZONE, 'UTC');
END getutcdate;
/

-- Example:
-- SELECT getutcdate(), SYSTIMESTAMP, DBTIMEZONE;

-- EOF
