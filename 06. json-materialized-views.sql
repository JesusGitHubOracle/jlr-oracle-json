 
 
 


---------------------------------------------------------------------------------
-- Materialized  Views over JSON Data with ROWID and PRIMARY KEY
-- PURCHASEORDERS collection table 
---------------------------------------------------------------------------------

-- Creating Materialized view with ROWID 
-- Each LineItems element becomes a separate MV row. ROWID identifies the
-- source collection row, allowing fast refresh and joins back to PURCHASEORDERS.
DROP MATERIALIZED VIEW JSON_PO_MV_ROWID;
CREATE MATERIALIZED VIEW JSON_PO_MV_ROWID
BUILD IMMEDIATE
REFRESH FAST ON STATEMENT WITH ROWID
AS
SELECT po.rowid as id, po.*
FROM PURCHASEORDERS po,
      -- JSON_TABLE projects scalar order fields and unnests LineItems and Part.
      -- The nested paths preserve the parent purchase-order relationship.
      JSON_TABLE (po.DATA, '$' error on error null on empty
            COLUMNS (ponumber  number         PATH '$.PONumber',
                     requestor varchar2(32)   PATH '$.Requestor',
                     special   varchar2(30)   PATH '$."Special Instructions"',
                     NESTED PATH '$.LineItems[*]'
                     COLUMNS
                     ( itemnumber number PATH '$.ItemNumber', 
                        NESTED PATH '$.Part[*]'
                        COLUMNS ( 
                        itemdesc varchar2(256) PATH '$.Description',
                        upccode  number PATH '$.UPCCode',
                        unitprice number PATH '$.UnitPrice')
                        )));


-- Explain Plan
EXPLAIN PLAN FOR 
SELECT * FROM JSON_PO_MV_ROWID;
SELECT PLAN_TABLE_OUTPUT FROM TABLE(DBMS_XPLAN.DISPLAY());
/*
--------------------------------------------------------------------------------------------------------------------------------- 
| Id  | Operation                       | Name             | Rows  | Bytes | Cost (%CPU)| Time     |    TQ  |IN-OUT| PQ Distrib | 
--------------------------------------------------------------------------------------------------------------------------------- 
|   0 | SELECT STATEMENT                |                  | 45260 |    38M|   234   (1)| 00:00:01 |        |      |            | 
|   1 |  PX COORDINATOR                 |                  |       |       |            |          |        |      |            | 
|   2 |   PX SEND QC (RANDOM)           | :TQ10000         | 45260 |    38M|   234   (1)| 00:00:01 |  Q1,00 | P->S | QC (RAND)  | 
|   3 |    PX BLOCK ITERATOR            |                  | 45260 |    38M|   234   (1)| 00:00:01 |  Q1,00 | PCWC |            | 
|   4 |     MAT_VIEW ACCESS STORAGE FULL| JSON_PO_MV_ROWID | 45260 |    38M|   234   (1)| 00:00:01 |  Q1,00 | PCWP |            | 
--------------------------------------------------------------------------------------------------------------------------------- 
*/


-- Creating Materialized view with PRIMARY KEY
-- RESID is the collection's internal document identifier. This form supports
-- query rewrite back to the JSON collection through the collection key.
      
DROP MATERIALIZED VIEW JSON_PO_MV_PK;          
CREATE MATERIALIZED VIEW JSON_PO_MV_PK BUILD IMMEDIATE
REFRESH FAST ON STATEMENT WITH PRIMARY KEY
AS SELECT po.resid, jt.*
FROM PURCHASEORDERS po,
      JSON_TABLE (po.DATA, '$' error on error null on empty
            COLUMNS (ponumber  number         PATH '$.PONumber',
                     requestor varchar2(32)   PATH '$.Requestor',
                     special   varchar2(30)   PATH '$."Special Instructions"',
                     NESTED PATH '$.LineItems[*]'
                     COLUMNS
                     ( itemnumber number PATH '$.ItemNumber', 
                        NESTED PATH '$.Part[*]'
                        COLUMNS ( 
                        itemdesc varchar2(256) PATH '$.Description',
                        upccode  number PATH '$.UPCCode',
                        unitprice number PATH '$.UnitPrice')
                        ))) jt;


EXPLAIN PLAN FOR  SELECT * FROM JSON_PO_MV_PK; 
select  PLAN_TABLE_OUTPUT FROM TABLE(DBMS_XPLAN.DISPLAY());

/*
------------------------------------------------------------------------------------------------------------------------------ 
| Id  | Operation                       | Name          | Rows  | Bytes | Cost (%CPU)| Time     |    TQ  |IN-OUT| PQ Distrib | 
------------------------------------------------------------------------------------------------------------------------------ 
|   0 | SELECT STATEMENT                |               | 45260 |  3535K|    23   (0)| 00:00:01 |        |      |            | 
|   1 |  PX COORDINATOR                 |               |       |       |            |          |        |      |            | 
|   2 |   PX SEND QC (RANDOM)           | :TQ10000      | 45260 |  3535K|    23   (0)| 00:00:01 |  Q1,00 | P->S | QC (RAND)  | 
|   3 |    PX BLOCK ITERATOR            |               | 45260 |  3535K|    23   (0)| 00:00:01 |  Q1,00 | PCWC |            | 
|   4 |     MAT_VIEW ACCESS STORAGE FULL| JSON_PO_MV_PK | 45260 |  3535K|    23   (0)| 00:00:01 |  Q1,00 | PCWP |            | 
------------------------------------------------------------------------------------------------------------------------------ 
*/

set define off
explain plan for SELECT po.data FROM purchaseorders po
  WHERE json_exists(po.data,
                    '$?(@.PONumber == 25
                        && exists(@.LineItems[*]?(
                                   @.Part.UPCCode == 85391264828
                                    && @.Quantity > 3)))'); 
 
 

select  PLAN_TABLE_OUTPUT FROM TABLE(DBMS_XPLAN.DISPLAY());

 /*
                                                                                                                                     
----------------------------------------------------------------------------------------------------------------------------------- 
| Id  | Operation                           | Name           | Rows  | Bytes | Cost (%CPU)| Time     |    TQ  |IN-OUT| PQ Distrib | 
----------------------------------------------------------------------------------------------------------------------------------- 
|   0 | SELECT STATEMENT                    |                |     1 |   898 |    24   (5)| 00:00:01 |        |      |            | 
|   1 |  PX COORDINATOR                     |                |       |       |            |          |        |      |            | 
|   2 |   PX SEND QC (RANDOM)               | :TQ10001       |     1 |   898 |    24   (5)| 00:00:01 |  Q1,01 | P->S | QC (RAND)  | 
|   3 |    NESTED LOOPS                     |                |     1 |   898 |    24   (5)| 00:00:01 |  Q1,01 | PCWP |            | 
|   4 |     SORT UNIQUE                     |                |     1 |    26 |    23   (0)| 00:00:01 |  Q1,01 | PCWP |            | 
|   5 |      PX RECEIVE                     |                |     1 |    26 |    23   (0)| 00:00:01 |  Q1,01 | PCWP |            | 
|   6 |       PX SEND HASH                  | :TQ10000       |     1 |    26 |    23   (0)| 00:00:01 |  Q1,00 | P->P | HASH       | 
|   7 |        PX BLOCK ITERATOR            |                |     1 |    26 |    23   (0)| 00:00:01 |  Q1,00 | PCWC |            | 
|*  8 |         MAT_VIEW ACCESS STORAGE FULL| JSON_PO_MV_PK  |     1 |    26 |    23   (0)| 00:00:01 |  Q1,00 | PCWP |            | 
|*  9 |     TABLE ACCESS BY INDEX ROWID     | PURCHASEORDERS |     1 |   872 |     0   (0)| 00:00:01 |  Q1,01 | PCWP |            | 
|* 10 |      INDEX UNIQUE SCAN              | SYS_C0033332   |     1 |       |     0   (0)| 00:00:01 |  Q1,01 | PCWP |            | 
----------------------------------------------------------------------------------------------------------------------------------- 
 */


------- Query Rewrite
-- Drop existing MV 

DROP MATERIALIZED VIEW JSON_PO_MV_PK; 

--create the MV for query rewrite
-- This MV exposes the JSON paths used by the later JSON_EXISTS predicates as
-- relational columns. Oracle can rewrite eligible JSON queries to this MV.
DROP MATERIALIZED VIEW mv_for_query_rewrite;  
CREATE MATERIALIZED VIEW mv_for_query_rewrite
  BUILD IMMEDIATE
  REFRESH FAST ON STATEMENT WITH PRIMARY KEY
  AS SELECT po.resid, jt.*
       FROM purchaseorders po,
            json_table(po.data, '$' ERROR ON ERROR NULL ON EMPTY
              COLUMNS (
                po_number       NUMBER         PATH '$.PONumber',
                userid          VARCHAR2(10)   PATH '$.User',
                NESTED PATH '$.LineItems[*]'
                  COLUMNS (
                    itemno      NUMBER         PATH '$.ItemNumber',
                    description VARCHAR2(256)  PATH '$.Part.Description',
                    upc_code    NUMBER         PATH '$.Part.UPCCode',
                    quantity    NUMBER         PATH '$.Quantity',
                    unitprice   NUMBER         PATH '$.Part.UnitPrice'))) jt;

---- &&
-- Disable SQL*Plus substitution so ampersands in JSON path expressions are
-- passed to the database unchanged.
SET DEFINE OFF
EXPLAIN PLAN for SELECT po.data FROM purchaseorders po
      WHERE JSON_EXISTS(po.data,
                    '$?(@.PONumber == 25
                        && exists(@.LineItems[*]?(
                                   @.Part.UPCCode == 85391264828
                                    && @.Quantity > 3)))'); 

SELECT PLAN_TABLE_OUTPUT FROM TABLE(DBMS_XPLAN.DISPLAY());
/*
----------------------------------------------------------------------------------------------------------------------------------------- 
| Id  | Operation                           | Name                 | Rows  | Bytes | Cost (%CPU)| Time     |    TQ  |IN-OUT| PQ Distrib | 
----------------------------------------------------------------------------------------------------------------------------------------- 
|   0 | SELECT STATEMENT                    |                      |     1 |   901 |    20   (5)| 00:00:01 |        |      |            | 
|   1 |  PX COORDINATOR                     |                      |       |       |            |          |        |      |            | 
|   2 |   PX SEND QC (RANDOM)               | :TQ10001             |     1 |   901 |    20   (5)| 00:00:01 |  Q1,01 | P->S | QC (RAND)  | 
|   3 |    NESTED LOOPS                     |                      |     1 |   901 |    20   (5)| 00:00:01 |  Q1,01 | PCWP |            | 
|   4 |     SORT UNIQUE                     |                      |     1 |    29 |    19   (0)| 00:00:01 |  Q1,01 | PCWP |            | 
|   5 |      PX RECEIVE                     |                      |     1 |    29 |    19   (0)| 00:00:01 |  Q1,01 | PCWP |            | 
|   6 |       PX SEND HASH                  | :TQ10000             |     1 |    29 |    19   (0)| 00:00:01 |  Q1,00 | P->P | HASH       | 
|   7 |        PX BLOCK ITERATOR            |                      |     1 |    29 |    19   (0)| 00:00:01 |  Q1,00 | PCWC |            | 
|*  8 |         MAT_VIEW ACCESS STORAGE FULL| MV_FOR_QUERY_REWRITE |     1 |    29 |    19   (0)| 00:00:01 |  Q1,00 | PCWP |            | 
|   9 |     TABLE ACCESS BY INDEX ROWID     | PURCHASEORDERS       |     1 |   872 |     0   (0)| 00:00:01 |  Q1,01 | PCWP |            | 
|* 10 |      INDEX UNIQUE SCAN              | SYS_C0033332         |     1 |       |     0   (0)| 00:00:01 |  Q1,01 | PCWP |            | 
----------------------------------------------------------------------------------------------------------------------------------------- 
*/

 

-- explain plan 
explain plan for SELECT po.data FROM purchaseorders po
  WHERE json_exists(po.data,
                    '$?(@.User == "ABULL"
                        && exists(@.LineItems[*]?(
                                    @.Part.UPCCode == 85391628927
                                    && @.Quantity > 3)))'); 
 
 SELECT PLAN_TABLE_OUTPUT FROM TABLE(DBMS_XPLAN.DISPLAY());
 

/*
Plan hash value: 1405009755                                                                                        
                                                                                                                   
-----------------------------------------------------------------------------------------------------              
| Id  | Operation                    | Name                 | Rows  | Bytes | Cost (%CPU)| Time     |              
-----------------------------------------------------------------------------------------------------              
|   0 | SELECT STATEMENT             |                      |     1 |  5137 |   131   (2)| 00:00:01 |              
|   1 |  NESTED LOOPS                |                      |     1 |  5137 |   131   (2)| 00:00:01 |              
|   2 |   SORT UNIQUE                |                      |     1 |    33 |   129   (1)| 00:00:01 |              
|*  3 |    MAT_VIEW ACCESS FULL      | MV_FOR_QUERY_REWRITE |     1 |    33 |   129   (1)| 00:00:01 |              
|   4 |   TABLE ACCESS BY INDEX ROWID| PURCHASEORDERS       |     1 |  5104 |     1   (0)| 00:00:01 |              
|*  5 |    INDEX UNIQUE SCAN         | SYS_C008438          |     1 |       |     0   (0)| 00:00:01 |              
-----------------------------------------------------------------------------------------------------              
                                                                                                                   
Predicate Information (identified by operation id):                                                                
---------------------------------------------------                                                                
                                                                                                                   
   3 - filter("SYS_JMV_1"."UPC_CODE"=85391628927 AND "SYS_JMV_1"."USERID"='ABULL' AND                              
              "SYS_JMV_1"."QUANTITY">3)                                                                            
   5 - access("SYS_JMV_1"."RESID"=JSON_VALUE("DATA" /*+ LOB_BY_VALUE    FORMAT OSON ,                             
              '$._id' RETURNING ANY ORA_RAWCOMPARE(2000) NO ARRAY ERROR ON ERROR TYPE(LAX) ))                      
                                                                                                                   
Note                                                                                                               
-----                                                                                                              
   - dynamic statistics used: dynamic sampling (level=2)                                                           

24 rows selected. 

You can tell whether the materialized view is used for a particular query by examining the execution plan. 
If it is, then the plan refers to mv_for_query_rewrite. For example:
|* 4| MAT_VIEW ACCESS FULL | MV_FOR_QUERY_REWRITE |1|51|3(0)|00:00:01|
*/
---
-- Index on a MV
-- This composite index supports the USERID, UPC_CODE, and QUANTITY filters
-- that are projected from the embedded LineItems objects.
drop INDEX MV_IDx;
CREATE INDEX mv_idx ON mv_for_query_rewrite(userid,
                                            upc_code,
                                            quantity);

explain plan for SELECT po.data FROM purchaseorders po
  WHERE json_exists(po.data,
                    '$?(@.User == "ABULL"
                        && exists(@.LineItems[*]?(
                                    @.Part.UPCCode == 85391628927
                                    && @.Quantity > 3)))'); 

SELECT PLAN_TABLE_OUTPUT FROM TABLE(DBMS_XPLAN.DISPLAY());
/*
PLAN_TABLE_OUTPUT                                                                                        
________________________________________________________________________________________________________ 
Plan hash value: 1405009755                                                                              
                                                                                                         
-----------------------------------------------------------------------------------------------------    
| Id  | Operation                    | Name                 | Rows  | Bytes | Cost (%CPU)| Time     |    
-----------------------------------------------------------------------------------------------------    
|   0 | SELECT STATEMENT             |                      |     1 |  5137 |   131   (2)| 00:00:01 |    
|   1 |  NESTED LOOPS                |                      |     1 |  5137 |   131   (2)| 00:00:01 |    
|   2 |   SORT UNIQUE                |                      |     1 |    33 |   129   (1)| 00:00:01 |    
|*  3 |    MAT_VIEW ACCESS FULL      | MV_FOR_QUERY_REWRITE |     1 |    33 |   129   (1)| 00:00:01 |    
|   4 |   TABLE ACCESS BY INDEX ROWID| PURCHASEORDERS       |     1 |  5104 |     1   (0)| 00:00:01 |    
|*  5 |    INDEX UNIQUE SCAN         | SYS_C008438          |     1 |       |     0   (0)| 00:00:01 |    
-----------------------------------------------------------------------------------------------------    
                                                                                                         
Predicate Information (identified by operation id):                                                      
---------------------------------------------------                                                      
                                                                                                         
   3 - filter("SYS_JMV_1"."UPC_CODE"=85391628927 AND "SYS_JMV_1"."USERID"='ABULL' AND                    
              "SYS_JMV_1"."QUANTITY">3)                                                                  
   5 - access("SYS_JMV_1"."RESID"=JSON_VALUE("DATA" /*+ LOB_BY_VALUE * FORMAT OSON ,                   
              '$._id' RETURNING ANY ORA_RAWCOMPARE(2000) NO ARRAY ERROR ON ERROR TYPE(LAX) ))            
                                                                                                         
Note                                                                                                     
-----                                                                                                    
   - dynamic statistics used: dynamic sampling (level=2)                                                 

24 rows selected. 
*/


-- Materialized view  aggregation                 
-- Pre-aggregate the extended price of every line item (quantity * unit price)
-- so purchase-order totals can be retrieved without reparsing each document.
DROP MATERIALIZED VIEW  mv_for_aggregation;
CREATE MATERIALIZED VIEW mv_for_aggregation
  AS SELECT jt.po_number, sum(jt.quantity * jt.unitprice) 
       FROM PURCHASEORDERS po,
            json_table(po.data, '$' ERROR ON ERROR NULL ON EMPTY
              COLUMNS (
                po_number       NUMBER         PATH '$.PONumber',
                userid          VARCHAR2(10)   PATH '$.User',
                NESTED PATH '$.LineItems[*]'
                  COLUMNS (
                    itemno      NUMBER         PATH '$.ItemNumber',
                    description VARCHAR2(256)  PATH '$.Part.Description',
                    upc_code    NUMBER         PATH '$.Part.UPCCode',
                    quantity    NUMBER         PATH '$.Quantity',
                    unitprice   NUMBER         PATH '$.Part.UnitPrice'))) jt 
          GROUP BY (jt.po_number);



explain plan for select * from mv_for_aggregation;

select  PLAN_TABLE_OUTPUT FROM TABLE(DBMS_XPLAN.DISPLAY());

/*
-----------------------------------------------------------------------------------------------------------------------------------    
| Id  | Operation                       | Name               | Rows  | Bytes | Cost (%CPU)| Time     |    TQ  |IN-OUT| PQ Distrib |    
-----------------------------------------------------------------------------------------------------------------------------------    
|   0 | SELECT STATEMENT                |                    | 10000 | 90000 |     6   (0)| 00:00:01 |        |      |            |    
|   1 |  PX COORDINATOR                 |                    |       |       |            |          |        |      |            |    
|   2 |   PX SEND QC (RANDOM)           | :TQ10000           | 10000 | 90000 |     6   (0)| 00:00:01 |  Q1,00 | P->S | QC (RAND)  |    
|   3 |    PX BLOCK ITERATOR            |                    | 10000 | 90000 |     6   (0)| 00:00:01 |  Q1,00 | PCWC |            |    
|   4 |     MAT_VIEW ACCESS STORAGE FULL| MV_FOR_AGGREGATION | 10000 | 90000 |     6   (0)| 00:00:01 |  Q1,00 | PCWP |            |    
-----------------------------------------------------------------------------------------------------------------------------------     
*/
 

/*
  Search embeddedDocument query for the PURCHASEORDERS collection.

  Every LineItems[*] object is materialized as one row. Thus predicates on
  QUANTITY and UNIT_PRICE, and Oracle Text matching on DESCRIPTION, all apply
  to the same embedded LineItems element.

  Run as the owner of PURCHASEORDERS. The collection itself is not altered.
*/

-- Drop the existing line-item search materialized view, if present...

 drop materialized view purchaseorders_lineitems_mv;   
 

--  Create or configure the Oracle Text wordlist...
BEGIN
  ctx_ddl.drop_preference('purchaseorders_li_wordlist');
END;
/

 BEGIN
    ctx_ddl.create_preference(
      'purchaseorders_li_wordlist',
      'BASIC_WORDLIST'
    );

  ctx_ddl.set_attribute(
    'purchaseorders_li_wordlist', 'PREFIX_INDEX', 'TRUE'
  );
  ctx_ddl.set_attribute(
    'purchaseorders_li_wordlist', 'PREFIX_MIN_LENGTH', '3'
  );
  ctx_ddl.set_attribute(
    'purchaseorders_li_wordlist', 'PREFIX_MAX_LENGTH', '12'
  );
end;
/

--  Materialize one row per embedded LineItems element...

create materialized view purchaseorders_lineitems_mv
  build immediate
  refresh complete on demand
as
select
  po.rowid as source_rowid,
  json_value(po.data, '$.PONumber' returning number
             null on empty null on error) as po_number,
  li.item_number,
  li.description,
  li.unit_price,
  li.upc_code,
  li.quantity
from purchaseorders po
cross join json_table(
  po.data,
  '$.LineItems[*]'
  columns (
    item_number number          path '$.ItemNumber',
    description varchar2(1000)  path '$.Part.Description',
    unit_price  number          path '$.Part.UnitPrice',
    upc_code    number          path '$.Part.UPCCode',
    quantity    number          path '$.Quantity'
  )
) li
where li.description is not null;

--  Create indexes for text and structured line-item predicates...

create index purchaseorders_li_text_idx
  on purchaseorders_lineitems_mv (description)
  indextype is ctxsys.context
  parameters (
    'WORDLIST purchaseorders_li_wordlist
     SYNC (ON COMMIT)'
  );

create index purchaseorders_li_price_qty_ix
  on purchaseorders_lineitems_mv (unit_price, quantity);

--  Example: same embedded LineItems object must satisfy every predicate...

select
  po_number,
  item_number,
  description,
  unit_price,
  quantity,
  score(1) as relevance
from purchaseorders_lineitems_mv
where unit_price >= 20
  and quantity >= 5
  and contains(description, 'star%', 1) > 0
order by score(1) desc, po_number, item_number;

/*

   PO_NUMBER    ITEM_NUMBER DESCRIPTION                                    UNIT_PRICE    QUANTITY    RELEVANCE 
____________ ______________ ___________________________________________ _____________ ___________ ____________ 
           2              4 Stardom                                             27.95           8            9 
          51              4 Roughnecks: Starship Troopers Chronicles            27.95           8            9 
         508              1 Stargate                                            27.95           8            9 
         927              4 Stargate & Moon 44                                  32.95           6            9 
        1047              2 Stardom                                             27.95           7            9 
        1259              1 Stargate                                            27.95           7            9 
        1392              3 Star Trek: First Contact                            27.95           5            9 
        1429              4 Stargate & Moon 44                                  32.95           8            9 
        1664              3 Stargate                                            27.95           7            9 
        1785              3 Stargate                                            27.95           7            9 
        1789              2 Starry Night                                        27.95           5            9 
        1825              5 Child Star: The Shirley Temple Story                27.95           9            9 
        1839              2 Star Trek: The Motion Picture                       32.95           7            9 
*/

explain plan for
select
  po_number,
  item_number,
  description,
  unit_price,
  quantity,
  score(1) as relevance
from purchaseorders_lineitems_mv
where unit_price >= 20
  and quantity >= 5
  and contains(description, 'star%', 1) > 0
order by score(1) desc, po_number, item_number;
select * from dbms_xplan.display();



/*
-----------------------------------------------------------------------------------------------------------------------------------------------------------    
| Id  | Operation                                   | Name                           | Rows  | Bytes | Cost (%CPU)| Time     |    TQ  |IN-OUT| PQ Distrib |    
-----------------------------------------------------------------------------------------------------------------------------------------------------------    
|   0 | SELECT STATEMENT                            |                                |    60 |  2880 |   142   (2)| 00:00:01 |        |      |            |    
|   1 |  PX COORDINATOR                             |                                |       |       |            |          |        |      |            |    
|   2 |   PX SEND QC (ORDER)                        | :TQ10002                       |    60 |  2880 |   142   (2)| 00:00:01 |  Q1,02 | P->S | QC (ORDER) |    
|   3 |    SORT ORDER BY                            |                                |    60 |  2880 |   142   (2)| 00:00:01 |  Q1,02 | PCWP |            |    
|   4 |     PX RECEIVE                              |                                |    60 |  2880 |   141   (1)| 00:00:01 |  Q1,02 | PCWP |            |    
|   5 |      PX SEND RANGE                          | :TQ10001                       |    60 |  2880 |   141   (1)| 00:00:01 |  Q1,01 | P->P | RANGE      |    
|   6 |       MAT_VIEW ACCESS BY INDEX ROWID BATCHED| PURCHASEORDERS_LINEITEMS_MV    |    60 |  2880 |   141   (1)| 00:00:01 |  Q1,01 | PCWP |            |    
|   7 |        BUFFER SORT                          |                                |       |       |            |          |  Q1,01 | PCWC |            |    
|   8 |         PX RECEIVE                          |                                |       |       |            |          |  Q1,01 | PCWP |            |    
|   9 |          PX SEND HASH (BLOCK ADDRESS)       | :TQ10000                       |       |       |            |          |        | S->P | HASH (BLOCK|    
|  10 |           BITMAP CONVERSION TO ROWIDS       |                                |       |       |            |          |        |      |            |    
|  11 |            BITMAP AND                       |                                |       |       |            |          |        |      |            |    
|  12 |             BITMAP CONVERSION FROM ROWIDS   |                                |       |       |            |          |        |      |            |    
|  13 |              SORT ORDER BY                  |                                |       |       |            |          |        |      |            |    
|* 14 |               INDEX RANGE SCAN              | PURCHASEORDERS_LI_PRICE_QTY_IX |       |       |    22   (0)| 00:00:01 |        |      |            |    
|  15 |             BITMAP CONVERSION FROM ROWIDS   |                                |       |       |            |          |        |      |            |    
|  16 |              SORT ORDER BY                  |                                |       |       |            |          |        |      |            |    
|* 17 |               DOMAIN INDEX                  | PURCHASEORDERS_LI_TEXT_IDX     |       |       |   106   (0)| 00:00:01 |        |      |            |    
-----------------------------------------------------------------------------------------------------------------------------------------------------------    
                                                                                                                                                               
Predicate Information (identified by operation id):                                                                                                            
---------------------------------------------------                                                                                                            
                                                                                                                                                               
  14 - access("UNIT_PRICE">=20 AND "QUANTITY">=5)                                                                                                              
       filter("QUANTITY">=5 AND "UNIT_PRICE">=20)                                                                                                              
  17 - access("CTXSYS"."CONTAINS"("DESCRIPTION",'star%',1)>0)                                                                                                  
                                                                                                                                                               
Note                                                                                                                                                           
-----                                                                                                                                                          



*/
prompt Refresh after loading or changing purchase orders:
prompt begin dbms_mview.refresh('PURCHASEORDERS_LINEITEMS_MV', 'C'); end;
prompt /
