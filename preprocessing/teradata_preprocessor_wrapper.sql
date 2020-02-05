alter session set SQL_PREPROCESSOR_SCRIPT = PREPROCESSING.TeradataPre;
alter session set SQL_PREPROCESSOR_SCRIPT = '';
 
--/
create or replace script preprocessing.TeradataPre() as
import ('PREPROCESSING.TRANSFORMATIONS', 'TRANS')
sqltext = sqlparsing.getsqltext()
sqlparsing.setsqltext(TRANS.like_all_any(sqltext))
/

SELECT * FROM retail.article WHERE description LIKE ALL('%in%',/*some comment*/'%Mix%','%c%') and description like all('%ini%', '%x%');
SELECT * FROM retail.article WHERE description LIKE ALL('%in%',/*some comment*/'%Mix%','%c%') and description like any('%ini%', '%x%');
select * from retail.article where description like all('%in%', '%ins%') and (description like any('%in%', '%in%') or description like all ('%ba%','%ce%'));