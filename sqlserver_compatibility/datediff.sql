/*

    This function is a compatibility implementation of MS SQL Server's DATEDIFF function.
    It returns the count (as a signed integer value) of the specified datepart boundaries
    crossed between the specified startdate and enddate.

*/

CREATE SCHEMA IF NOT EXISTS EXA_toolbox;

--/
CREATE OR REPLACE FUNCTION EXA_toolbox.datediff(p_datepart IN VARCHAR(20), p_start_date_expr IN TIMESTAMP, p_end_date_expr IN TIMESTAMP)
    RETURN NUMBER IS

    v_ret_value    NUMBER;
    v_part         VARCHAR(15);
    v_start_ts_tz  TIMESTAMP ;
    v_end_ts_tz    TIMESTAMP;
    v_start_date   DATE;
    v_end_date     DATE;

BEGIN
    v_ret_value   := NULL;
    v_part        := p_datepart;
    v_start_ts_tz := p_start_date_expr;
    v_end_ts_tz   := p_end_date_expr;
    v_start_date  := TRUNC(v_start_ts_tz);
    v_end_date    := TRUNC(v_end_ts_tz);
    v_part        := UPPER(p_datepart);

    IF v_part IN ('YEAR', 'YY', 'YYYY') THEN
        IF EXTRACT(YEAR FROM v_end_ts_tz) - EXTRACT(YEAR FROM v_start_ts_tz) = 1 AND
            EXTRACT(MONTH FROM v_start_ts_tz) = 12 AND EXTRACT(MONTH FROM v_end_ts_tz) = 1 AND
            EXTRACT(DAY FROM v_start_ts_tz) = 31 AND EXTRACT(DAY FROM v_end_ts_tz) = 1 THEN
            -- When comparing December 31 to January 1 of the immediately succeeding year,
            -- DateDiff for Year ("yyyy") returns 1, even though only a day has elapsed.
            v_ret_value := 1;
        ELSE
            v_ret_value := ROUND(MONTHS_BETWEEN(v_end_ts_tz, v_start_ts_tz) / 12);
        END IF;
    ELSIF v_part IN ('QUARTER', 'QQ', 'Q') THEN
        v_ret_value := ROUND(MONTHS_BETWEEN(v_end_ts_tz, v_start_ts_tz) / 3);
    ELSIF v_part IN ('MONTH', 'MM', 'M') THEN
        v_ret_value := ROUND(MONTHS_BETWEEN(TRUNC(v_end_ts_tz, 'MM'), TRUNC(v_start_ts_tz, 'MM')));
    ELSIF v_part IN ('DAYOFYEAR', 'DY', 'Y') THEN
        v_ret_value := ROUND(CAST(v_end_ts_tz AS DATE) - CAST(v_start_ts_tz AS DATE));
    ELSIF v_part IN ('DAY', 'DD', 'D') THEN
        v_ret_value :=DAYS_BETWEEN(v_end_date,v_start_date);
    ELSIF v_part IN ('WEEK', 'WK', 'WW') THEN
        v_ret_value := ROUND((CAST(v_end_ts_tz AS DATE) - CAST(v_start_ts_tz AS DATE)) / 7);
    ELSIF v_part IN ('WEEKDAY', 'DW', 'W') THEN
        IF EXTRACT(YEAR FROM v_end_ts_tz) = EXTRACT(YEAR FROM v_start_ts_tz) THEN
            v_ret_value := EXTRACT(DAY FROM v_end_ts_tz) - EXTRACT(DAY FROM v_start_ts_tz);
        ELSE
            v_ret_value := ROUND((days_between( TRUNC(v_end_ts_tz, 'DD') , TRUNC(v_start_ts_tz, 'DD') ) ) / 7);
        END IF;
    ELSIF v_part IN ('HOUR', 'HH') THEN
        v_ret_value := ROUND(v_end_date - v_start_date) * 24;
        v_ret_value := ROUND(v_ret_value + ((EXTRACT(HOUR FROM v_end_ts_tz) - EXTRACT(HOUR FROM v_start_ts_tz))));
    ELSIF v_part IN ('MINUTE', 'MI', 'N') THEN
        v_ret_value := ROUND(v_end_date - v_start_date) * 24 * 60;
        v_ret_value := v_ret_value + ((EXTRACT(HOUR FROM v_end_ts_tz) - EXTRACT(HOUR FROM v_start_ts_tz)) * 60);
        v_ret_value := ROUND(v_ret_value + ((EXTRACT(MINUTE FROM v_end_ts_tz) - EXTRACT(MINUTE FROM v_start_ts_tz))));
    ELSIF v_part IN ('SECOND', 'SS', 'S') THEN
        v_ret_value := ROUND(v_end_date - v_start_date) * 24 * 60 * 60;
        v_ret_value := v_ret_value + ((EXTRACT(HOUR FROM v_end_ts_tz) - EXTRACT(HOUR FROM v_start_ts_tz)) * 60 * 60);
        v_ret_value := v_ret_value + ((EXTRACT(MINUTE FROM v_end_ts_tz) - EXTRACT(MINUTE FROM v_start_ts_tz))  * 60);
        v_ret_value := ROUND(v_ret_value + ((EXTRACT(SECOND FROM v_end_ts_tz) - EXTRACT(SECOND FROM v_start_ts_tz))));
    ELSIF v_part IN ('MILLISECOND', 'MS') THEN
        v_ret_value := ROUND(v_end_date - v_start_date) * 24 * 60 * 60 * 1000;
        v_ret_value := v_ret_value + ((EXTRACT(HOUR FROM v_end_ts_tz) - EXTRACT(HOUR FROM v_start_ts_tz)) * 60 * 60 * 1000);
        v_ret_value := v_ret_value + ((EXTRACT(MINUTE FROM v_end_ts_tz) - EXTRACT(MINUTE FROM v_start_ts_tz))  * 60 * 1000);
        v_ret_value := ROUND(v_ret_value + ((EXTRACT(SECOND FROM v_end_ts_tz) - EXTRACT(SECOND FROM v_start_ts_tz)) * 1000));
    ELSIF v_part IN ('MICROSECOND', 'MCS') THEN
        v_ret_value := ROUND(v_end_date - v_start_date) * 24 * 60 * 60 * 1000000;
        v_ret_value := v_ret_value + ((EXTRACT(HOUR FROM v_end_ts_tz) - EXTRACT(HOUR FROM v_start_ts_tz)) * 60 * 60 * 1000000);
        v_ret_value := v_ret_value + ((EXTRACT(MINUTE FROM v_end_ts_tz) - EXTRACT(MINUTE FROM v_start_ts_tz))  * 60 * 1000000);
        v_ret_value := ROUND(v_ret_value + ((EXTRACT(SECOND FROM v_end_ts_tz) - EXTRACT(SECOND FROM v_start_ts_tz)) * 1000000));
    ELSIF v_part IN ('NANOSECOND', 'NS') THEN
        v_ret_value := ROUND(v_end_date - v_start_date) * 24 * 60 * 60 * 1000000000;
        v_ret_value := v_ret_value + ((EXTRACT(HOUR FROM v_end_ts_tz) - EXTRACT(HOUR FROM v_start_ts_tz)) * 60 * 60 * 1000000000);
        v_ret_value := v_ret_value + ((EXTRACT(MINUTE FROM v_end_ts_tz) - EXTRACT(MINUTE FROM v_start_ts_tz))  * 60 * 1000000000);
        v_ret_value := ROUND(v_ret_value + ((EXTRACT(SECOND FROM v_end_ts_tz) - EXTRACT(SECOND FROM v_start_ts_tz)) * 1000000000));
    END IF;

    RETURN v_ret_value;

END datediff;
/

-- Examples:
-- SELECT datediff('MONTH', SYSDATE, SYSDATE + 365);
-- SELECT datediff('HOUR', SYSDATE, SYSDATE + 7);

-- EOF