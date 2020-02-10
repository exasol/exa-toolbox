/*

    This function is a partial compatibility implementation of MS SQL Server's PATINDEX function.
    It returns the startposition of the first occurence of a given pattern in a VARCHAR

*/

create schema if not exists EXA_toolbox;

--/
create or replace FUNCTION EXA_toolbox.PATINDEX(p_pattern IN VARCHAR2(4000), p_expr IN VARCHAR2(4000))
RETURN NUMBER
IS
	p_format VARCHAR2(4000);
    v_search_pattern VARCHAR2(100);
    v_pos NUMBER;
    v_charsfmt VARCHAR2(20);
    v_charactersfmt  VARCHAR2(20);
    v_bytesfmt VARCHAR2(20);
    v_format VARCHAR2(20);
    v_errmsg VARCHAR2(50);
BEGIN
	p_format := 'USING CHARS';
    v_pos := 0;
    v_charsfmt := 'using chars';
    v_charactersfmt := 'using characters';
    v_bytesfmt := 'using bytes';
    v_errmsg := 'Invalid format: ';

      IF p_pattern IS NULL OR p_expr IS NULL THEN
         RETURN NULL;
      END IF;

      IF NOT FALSE THEN      
--      IF NOT DBMS_DB_VERSION.VER_LE_9_2 THEN
        v_search_pattern := p_pattern;
        v_search_pattern := REPLACE(v_search_pattern, '\', '\\');
        v_search_pattern := REPLACE(v_search_pattern, '*', '\*');
        v_search_pattern := REPLACE(v_search_pattern, '+', '\+');
        v_search_pattern := REPLACE(v_search_pattern, '?', '\?');
        v_search_pattern := REPLACE(v_search_pattern, '|', '\|');
        v_search_pattern := REPLACE(v_search_pattern, '^', '\^');
        v_search_pattern := REPLACE(v_search_pattern, '$', '\$');
        v_search_pattern := REPLACE(v_search_pattern, '.', '\.');
        v_search_pattern := REPLACE(v_search_pattern, '{', '\{');
        v_search_pattern := REPLACE(v_search_pattern, '_', '.');
              
        v_format := lower(p_format);
        IF v_format = v_charsfmt OR v_format = v_charactersfmt THEN
           IF SUBSTR(v_search_pattern, 1, 1) != '%' AND 
              SUBSTR(v_search_pattern, -1, 1) != '%' THEN
               v_search_pattern := '^' || v_search_pattern || '$';
           ELSIF SUBSTR(v_search_pattern, 1, 1) != '%' THEN
               v_search_pattern := '^' || SUBSTR(v_search_pattern, 1, LENGTH(v_search_pattern) - 1);
           ELSIF SUBSTR(v_search_pattern, -1, 1) != '%' THEN
               v_search_pattern := SUBSTR(v_search_pattern, 2) || '$';
           ELSE
               v_search_pattern := SUBSTR(v_search_pattern, 2, LENGTH(v_search_pattern) - 2);
           END IF;    
        ELSIF v_format = v_bytesfmt THEN    
           IF SUBSTR(v_search_pattern, 1, 1) != '%' AND 
              SUBSTR(v_search_pattern, -1, 1) != '%' THEN
               v_search_pattern := '^' || v_search_pattern || '$';
           ELSIF SUBSTR(v_search_pattern, 1, 1) != '%' THEN
               v_search_pattern := '^' || SUBSTR(v_search_pattern, 1, LENGTH(v_search_pattern) - 1);
           ELSIF SUBSTR(v_search_pattern, -1, 1) != '%' THEN
               v_search_pattern := SUBSTR(v_search_pattern, 2) || '$';
           ELSE
               v_search_pattern := SUBSTR(v_search_pattern, 2, LENGTH(v_search_pattern) - 2);
           END IF;    
        ELSE
              v_errmsg := 1/0;
--            v_errmsg := v_errmsg || p_format;
--            raise_application_error(-20001, v_errmsg);
        END IF;
        v_pos := REGEXP_INSTR(p_expr, v_search_pattern);
      ELSE 
        v_pos := 0;
      END IF;
      
      RETURN v_pos;
--EXCEPTION
--    WHEN OTHERS THEN
--      raise_application_error(-20000, DBMS_UTILITY.FORMAT_ERROR_STACK);
END PATINDEX;
/

-- Example:
-- SELECT PATINDEX('%sol%', 'Exasol');  

-- EOF