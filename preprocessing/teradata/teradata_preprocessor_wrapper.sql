alter session set SQL_PREPROCESSOR_SCRIPT = PREPROCESSING.TeradataPre;
alter session set SQL_PREPROCESSOR_SCRIPT = '';
 
--/
create or replace script preprocessing.TeradataPre() as
 import ('PREPROCESSING.TRANSFORMATIONS', 'TRANS')
 local sqltext = sqlparsing.getsqltext()
 sqltext = TRANS.not_equal(sqltext)
 sqltext = TRANS.like_all_any(sqltext)
 sqltext = TRANS.index_to_locate(sqltext)
 
 sqlparsing.setsqltext(sqltext)
/

--all/any
--SELECT * FROM retail.article WHERE description LIKE ALL('%in%',/*some comment*/'%Mix%','%c%') and description like all('%ini%', '%x%');
--SELECT * FROM retail.article WHERE description LIKE any('%in%',/*some comment*/'%Mix%','%c%') and description like all('%ini%', '%x%');
--select * from retail.article where description like all('%in%', '%ins%') and (description like any('%in%', '%in%') or description like all ('%ba%','%ce%'));

--index
--select locate('oma', description) as col1 from retail.article where locate('oma', description) > 0;
--select index(description, 'oma') as col1 from retail.article where index(description, 'oma') > 0;

--NE
--select * from retail.article where product_class NE 1;