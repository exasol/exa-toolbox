/*

    This function is a compatibility implementation of MS SQL Server's DATENAME function.
    It returns a character string representing the specified datepart of the specified date.

*/

CREATE SCHEMA IF NOT EXISTS EXA_toolbox;

--/
CREATE OR REPLACE FUNCTION EXA_toolbox.datename(p_part_expr IN VARCHAR(15), p_date_expr IN TIMESTAMP ) RETURN VARCHAR(30) IS

  v_part       VARCHAR(15);
  v_timestamp  TIMESTAMP;
  v_wkday      VARCHAR(10);
  v_year       VARCHAR( 4);
  v_temp       VARCHAR(30);

BEGIN

    v_timestamp := p_date_expr;
    v_part      := UPPER(p_part_expr);
    IF    v_part IN ('YEAR', 'YY', 'YYYY')   THEN RETURN TO_CHAR(v_timestamp, 'YYYY' );
    ELSIF v_part IN ('QUARTER', 'QQ', 'Q')   THEN RETURN TO_CHAR(v_timestamp, 'Q'    );
    ELSIF v_part IN ('MONTH', 'MM', 'M')     THEN RETURN TO_CHAR(v_timestamp, 'Month');
    ELSIF v_part IN ('DAYOFYEAR', 'DY', 'Y') THEN RETURN TO_CHAR(v_timestamp, 'DDD'  );
    ELSIF v_part IN ('DAY', 'DD', 'D')       THEN RETURN TO_CHAR(v_timestamp, 'DD'   );
    ELSIF v_part IN ('WEEKDAY', 'DW', 'W')   THEN RETURN TO_CHAR(v_timestamp, 'Day'  );
    ELSIF v_part IN ('WEEK', 'WK', 'WW')     THEN RETURN TO_CHAR(v_timestamp, 'WW'   );
    ELSIF v_part IN ('HOUR', 'HH')           THEN RETURN TO_CHAR(v_timestamp, 'HH24' );
    ELSIF v_part IN ('MINUTE', 'MI', 'N')    THEN RETURN TO_CHAR(v_timestamp, 'MI'   );
    ELSIF v_part IN ('SECOND', 'SS', 'S')    THEN RETURN TO_CHAR(v_timestamp, 'SS'   );
    ELSIF v_part IN ('MILLISECOND', 'MS', 'FF3') THEN
        v_temp := TO_CHAR(v_timestamp, 'FF3');
        IF v_temp = '000' THEN
           RETURN '0';
        ELSE
           RETURN v_temp;
        END IF;
    ELSIF v_part IN ('MICROSECOND', 'MCS', 'FF6') THEN
        v_temp := TO_CHAR(v_timestamp, 'FF6');
        IF v_temp = '000000' THEN
           RETURN '0';
        ELSE
           RETURN v_temp;
        END IF;
    ELSIF v_part IN ('NANOSECOND', 'NS', 'FF9') THEN
        v_temp := TO_CHAR(v_timestamp, 'FF9');
        IF v_temp = '000000000' THEN
           RETURN '0';
        ELSE
           RETURN v_temp;
        END IF;
    ELSE
        RETURN NULL;
    END IF;
    RETURN NULL;

END datename;
/

-- Example:
-- SELECT DATENAME('YEAR', SYSTIMESTAMP);

-- EOF