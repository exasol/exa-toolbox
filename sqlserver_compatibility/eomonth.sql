/*

    This function is a compatibility implementation of MS SQL Server's EOMONTH function.
    It returns the last day of the month given.

*/

CREATE SCHEMA IF NOT EXISTS EXA_toolbox;

--/
CREATE OR REPLACE FUNCTION EXA_toolbox.EOMONTH(date_in IN TIMESTAMP)
    RETURN DATE IS


BEGIN

    RETURN DATE_TRUNC('month', date_in) + INTERVAL '1' MONTH - INTERVAL '1' DAY;

END EOMONTH;
/

-- Examples: 
--  SELECT EXA_toolbox.EOMONTH('2019-02-15');
--  SELECT EXA_toolbox.EOMONTH('2020-02-14');
--  SELECT EXA_toolbox.EOMONTH(current_timestamp) as last_day_of_month;

-- EOF 