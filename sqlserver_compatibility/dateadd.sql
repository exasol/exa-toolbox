/*

    This function is a compatibility implementation of MS SQL Server's DATEADD function.
    It adds a specified number value (as a signed integer) to a specified datepart
    of an input date value, and then returns that modified value.

*/

CREATE SCHEMA IF NOT EXISTS EXA_toolbox;

--/
CREATE OR REPLACE FUNCTION EXA_toolbox.dateadd(p_interval IN VARCHAR(11), p_interval_val IN NUMBER, p_date_exp IN TIMESTAMP)
    RETURN TIMESTAMP IS

    v_ucase_interval VARCHAR(11);
    v_date           TIMESTAMP;
    v_datestr        VARCHAR(30);
    v_result         TIMESTAMP;

BEGIN

    v_date           := CAST(p_date_exp AS TIMESTAMP);
    v_ucase_interval := UPPER(p_interval);
    IF v_ucase_interval IN ('YEAR', 'YY', 'YYYY') THEN
        RETURN ADD_MONTHS(v_date, p_interval_val * 12);
    ELSIF v_ucase_interval IN ('QUARTER', 'QQ', 'Q') THEN
        IF  ADD_DAYS(ADD_MONTHS(TRUNC(v_date, 'mm')  , 1 ), -1) = v_date THEN
            v_datestr := EXTRACT(MONTH FROM v_date) + (p_interval_val * 3);
            v_datestr := v_datestr || '-' || EXTRACT(DAY FROM v_date) || '-' || EXTRACT(YEAR FROM v_date);
            v_datestr := v_datestr || ' ' || TO_CHAR(v_date, 'HH12') || ':' || TO_CHAR(v_date, 'MI') || ':' || TO_CHAR(v_date, 'SS');
            v_datestr := v_datestr || '.' || TO_CHAR(v_date, 'FF3 AM') ;
            v_result := TO_TIMESTAMP(v_datestr, 'MM-DD-YYYY HH12:MI:SS.FF3 AM');
            RETURN v_result;
        ELSE
            RETURN ADD_MONTHS(v_date, p_interval_val * 3);
        END IF;
    ELSIF v_ucase_interval IN ('MONTH', 'MM', 'M') THEN
        -- Handle negative number
        IF p_interval_val < 0 THEN
            v_result := v_date - NUMTOYMINTERVAL(p_interval_val * -1, 'MONTH') + NUMTODSINTERVAL(0, 'HOUR');
        ELSE
            v_result := v_date + NUMTOYMINTERVAL(p_interval_val, 'MONTH') + NUMTODSINTERVAL(0, 'HOUR');
        END IF;
        RETURN v_result;
    ELSIF v_ucase_interval IN ('DAYOFYEAR', 'DY', 'Y', 'DAY', 'DD', 'D', 'WEEKDAY', 'DW', 'W') THEN
        RETURN v_date + NUMTODSINTERVAL(p_interval_val, 'DAY');
    ELSIF v_ucase_interval IN ('WEEK', 'WK', 'WW') THEN
        RETURN v_date + (p_interval_val * 7);
    ELSIF v_ucase_interval IN ('HOUR', 'HH') THEN
        RETURN v_date + NUMTODSINTERVAL(p_interval_val, 'HOUR');
    ELSIF v_ucase_interval IN ('MINUTE', 'MI', 'N') THEN
        RETURN v_date + NUMTODSINTERVAL(p_interval_val, 'MINUTE');
    ELSIF v_ucase_interval IN ('SECOND', 'SS', 'S') THEN
        RETURN v_date + NUMTODSINTERVAL(p_interval_val, 'SECOND');
    ELSIF v_ucase_interval IN ('MILLISECOND', 'MS') THEN
        -- Result accurate to one three-hundredth of a second
        RETURN v_date + NUMTODSINTERVAL(3.33 * ROUND(p_interval_val/3.33), 'SECOND')/1000;
    ELSE
        RETURN NULL;
    END IF;

    RETURN NULL;

END dateadd;
/

-- Examples:
-- SELECT dateadd('DAY', 7, SYSDATE);
-- SELECT dateadd('YEAR', 10, SYSDATE);

-- EOF
