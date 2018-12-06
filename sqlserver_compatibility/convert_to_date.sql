/*

    This function is a partial compatibility implementation of MS SQL Server's CONVERT function.
    It converts a string to a date using the specified style.

*/

CREATE SCHEMA IF NOT EXISTS EXA_toolbox;

--/
CREATE OR REPLACE FUNCTION convert_to_date(p_expr IN VARCHAR(200), p_style IN NUMBER ) RETURN DATE IS

    v_format VARCHAR(50);

BEGIN
    IF p_style IS NOT NULL THEN
        v_format := CASE WHEN p_style = 0   THEN 'MON DD YYYY HH12:MIAM'
                         WHEN p_style = 100 THEN 'MON DD YYYY HH12:MIAM'
                         WHEN p_style = 1   THEN 'MM/DD/YY'
                         WHEN p_style = 101 THEN 'MM/DD/YYYY'
                         WHEN p_style = 2   THEN 'YY.MM.DD'
                         WHEN p_style = 102 THEN 'YYYY.MM.DD'
                         WHEN p_style = 3   THEN 'DD/MM/YY'
                         WHEN p_style = 103 THEN 'DD/MM/YYYY'
                         WHEN p_style = 4   THEN 'DD.MM.YY'
                         WHEN p_style = 104 THEN 'DD.MM.YYYY'
                         WHEN p_style = 5   THEN 'DD-MM-YY'
                         WHEN p_style = 105 THEN 'DD-MM-YYYY'
                         WHEN p_style = 6   THEN 'DD Mon YY'
                         WHEN p_style = 106 THEN 'DD Mon YYYY'
                         WHEN p_style = 7   THEN 'Mon DD, YY'
                         WHEN p_style = 107 THEN 'Mon DD, YYYY'
                         WHEN p_style = 8   THEN 'HH24:MI:SS'
                         WHEN p_style = 108 THEN 'HH24:MI:SS'
                         WHEN p_style = 9   THEN 'FMMon  DD YYYY  HH12:MI:SS:FF3AM'
                         WHEN p_style = 109 THEN 'FMMon  DD YYYY  HH12:MI:SS:FF3AM'
                         WHEN p_style = 10  THEN 'MM-DD-YY'
                         WHEN p_style = 110 THEN 'MM-DD-YYYY'
                         WHEN p_style = 11  THEN 'YY/MM/DD'
                         WHEN p_style = 111 THEN 'YYYY/MM/DD'
                         WHEN p_style = 12  THEN 'YYMMDD'
                         WHEN p_style = 112 THEN 'YYYYMMDD'
                         WHEN p_style = 13  THEN 'DD Mon YYYY HH24:MI:SS:FF3'
                         WHEN p_style = 113 THEN 'DD Mon YYYY HH24:MI:SS:FF3'
                         WHEN p_style = 14  THEN 'HH24:MI:SS:FF3'
                         WHEN p_style = 114 THEN 'HH24:MI:SS:FF3'
                         WHEN p_style = 20  THEN 'YYYY-MM-DD HH24:MI:SS'
                         WHEN p_style = 120 THEN 'MM/DD/YY  HH12:MI:SS AM'
                         WHEN p_style = 21  THEN 'YYYY-MM-DD HH24:MI:SS.FF3'
                         WHEN p_style = 22  THEN 'MM/DD/YY  FMHH12:MI:SS AM'
                         WHEN p_style = 122 THEN 'MM/DD/YY  FMHH12:MI:SS AM'
                         WHEN p_style = 23  THEN 'YYYY-MM-DD'
                         WHEN p_style = 123 THEN 'YYYY-MM-DD'
                         WHEN p_style = 121 THEN 'YYYY-MM-DD HH24:MI:SS.FF3'
                         WHEN p_style = 126 THEN 'YYYY-MM-DD HH12:MI:SS.FF3'
                         WHEN p_style = 127 THEN 'YYYY-MM-DD HH12:MI:SS.FF3'
                         WHEN p_style = 130 THEN 'DD Mon YYYY HH12:MI:SS:FF3AM'
                         WHEN p_style = 131 THEN 'DD/MM/YY HH12:MI:SS:FF3AM'
                     END;
        RETURN TO_DATE(p_expr, v_format);
    ELSE
        RETURN CAST(p_expr AS DATE);
    END IF;

    RETURN p_expr;

END;
/

-- Example:
-- SELECT convert_to_date('2001-01-01', 123);

-- EOF