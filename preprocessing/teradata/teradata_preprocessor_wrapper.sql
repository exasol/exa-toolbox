alter session set SQL_PREPROCESSOR_SCRIPT = PREPROCESSING.TeradataPre;
alter session set SQL_PREPROCESSOR_SCRIPT = '';
 
--/
create or replace script preprocessing.TeradataPre() as
 import ('PREPROCESSING.TRANSFORMATIONS', 'TRANS')
 local sqltext = sqlparsing.getsqltext()
 sqltext = TRANS.not_equal(sqltext)
 sqltext = TRANS.like_all_any(sqltext)
 sqltext = TRANS.index_to_locate(sqltext)
 sqltext = TRANS.date_format_dql(sqltext)
 
 sqlparsing.setsqltext(sqltext)
/

--ALL/ANY
--SELECT * FROM retail.article WHERE description LIKE ALL('%in%',/*some comment*/'%Mix%','%c%') and description like all('%ini%', '%x%');
--SELECT * FROM retail.article WHERE description LIKE any('%in%',/*some comment*/'%Mix%','%c%') and description like all('%ini%', '%x%');
--select * from retail.article where description like all('%in%', '%ins%') and (description like any('%in%', '%in%') or description like all ('%ba%','%ce%'));

--INDEX
--select locate('oma', description) as col1 from retail.article where locate('oma', description) > 0;
--select description, index(description, 'oma') as col1 from retail.article where index(description, 'oma') > 0;

--NE
--select * from retail.article where product_class NE 2;

--DATE FORMAT
--SELECT 
--        CAST(
--                CAST(date_point AS FORMAT 'MM-DD-YYYY')
--        AS Varchar(10)) 
--AS col1
--FROM preprocessing.data_test;

--COMBINAION
--SELECT  a.description,
--        a.product_group_desc,
--        CAST(
--                CAST(s.sales_date AS FORMAT 'MM-DD-YYYY')
--                AS Varchar(10))
--                as col1,
--        index(a.product_group_desc, 'Food') as found_col,
--        a.product_class
--FROM retail.article a
--JOIN retail.sales s ON a.product_group = s.employee_id
--where index(a.description, 'Katze') > 0 and
--s.sales_date between '2014-01-01' and '2014-04-01' and
--a.product_class NE 1 and
--a.description LIKE ALL('%o%',/*some comment*/'%e%') 
--and a.product_group_desc like any('%et%',/*some comment*/ '%p%');