-- Summary: Materialized views over the PURCHASEORDERS JSON collection.
-- Covers ROWID and primary-key fast refresh, JSON query rewrite and indexing,
-- purchase-order totals, and Oracle Text searches within the same line item.
-- Includes execution-plan examples and on-demand refresh instructions.
-- Prerequisites: PURCHASEORDERS(DATA, RESID), with RESID as its primary key;
-- a database release supporting JSON_TABLE fast refresh ON STATEMENT;
-- Oracle Text and privileges to create materialized views, indexes and preferences.
-- Run as the collection owner in SQL*Plus, SQLcl or SQL Developer script mode.
-- UPCCode must be numeric in stored JSON (not an unconverted $numberLong object).
-- Sample plans/results are illustrative; actual optimizer choices can differ.

SET DEFINE OFF

---------------------------------------------------------------------------------
-- Materialized  Views over JSON Data with ROWID and PRIMARY KEY
-- PURCHASEORDERS collection table
---------------------------------------------------------------------------------

-- Creating Materialized view with ROWID
-- Each LineItems element becomes a separate MV row. ROWID identifies the
-- source collection row, allowing fast refresh and joins back to PURCHASEORDERS.
BEGIN
  EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW JSON_PO_MV_ROWID';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -12003 THEN
      RAISE;
    END IF;
END;
/
CREATE MATERIALIZED VIEW JSON_PO_MV_ROWID
BUILD IMMEDIATE
REFRESH FAST ON STATEMENT WITH ROWID
AS
SELECT po.rowid AS source_rowid, jt.*
FROM PURCHASEORDERS po,
      -- JSON_TABLE projects scalar order fields and unnests LineItems.
      -- The nested paths preserve the parent purchase-order relationship.
      JSON_TABLE (po.DATA, '$' error on error null on empty
            COLUMNS (ponumber  number         PATH '$.PONumber',
                     requestor varchar2(32)   PATH '$.Requestor',
                     special   varchar2(30)   PATH '$."Special Instructions"',
                     NESTED PATH '$.LineItems[*]'
                     COLUMNS
                     ( itemnumber NUMBER PATH '$.ItemNumber',
                       quantity   NUMBER PATH '$.Quantity',
                       itemdesc   VARCHAR2(256) PATH '$.Part.Description',
                       upccode    NUMBER PATH '$.Part.UPCCode',
                       unitprice  NUMBER PATH '$.Part.UnitPrice'
                     ))) jt;


-- Explain Plan
EXPLAIN PLAN FOR
SELECT * FROM JSON_PO_MV_ROWID;
SELECT PLAN_TABLE_OUTPUT FROM TABLE(DBMS_XPLAN.DISPLAY());
-- Sample output / notes:
-- -----------------------------------------------------------------------------------------
-- | Id  | Operation            | Name             | Rows  | Bytes | Cost (%CPU)| Time     |
-- -----------------------------------------------------------------------------------------
-- |   0 | SELECT STATEMENT     |                  | 45260 |    38M|  1639   (1)| 00:00:01 |
-- |   1 |  MAT_VIEW ACCESS FULL| JSON_PO_MV_ROWID | 45260 |    38M|  1639   (1)| 00:00:01 |
-- -----------------------------------------------------------------------------------------


-- Creating Materialized view with PRIMARY KEY
-- RESID is the collection's internal document identifier. This form supports
-- query rewrite back to the JSON collection through the collection key.
BEGIN
  EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW JSON_PO_MV_PK';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -12003 THEN
      RAISE;
    END IF;
END;
/
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
                     ( itemnumber NUMBER PATH '$.ItemNumber',
                       quantity   NUMBER PATH '$.Quantity',
                       itemdesc   VARCHAR2(256) PATH '$.Part.Description',
                       upccode    NUMBER PATH '$.Part.UPCCode',
                       unitprice  NUMBER PATH '$.Part.UnitPrice'
                     ))) jt;


EXPLAIN PLAN FOR  SELECT * FROM JSON_PO_MV_PK;
select  PLAN_TABLE_OUTPUT FROM TABLE(DBMS_XPLAN.DISPLAY());

-- Sample output / notes:
-- --------------------------------------------------------------------------------------
-- | Id  | Operation            | Name          | Rows  | Bytes | Cost (%CPU)| Time     |
-- --------------------------------------------------------------------------------------
-- |   0 | SELECT STATEMENT     |               | 45260 |  3535K|   153   (0)| 00:00:01 |
-- |   1 |  MAT_VIEW ACCESS FULL| JSON_PO_MV_PK | 45260 |  3535K|   153   (0)| 00:00:01 |
-- --------------------------------------------------------------------------------------

set define off
explain plan for SELECT po.data FROM purchaseorders po
  WHERE json_exists(po.data,
                    '$?(@.PONumber == 25
                        && exists(@.LineItems[*]?(
                                   @.Part.UPCCode == 85391264828
                                    && @.Quantity > 3)))');

select  PLAN_TABLE_OUTPUT FROM TABLE(DBMS_XPLAN.DISPLAY());

-- Sample output / notes:
-- 
-- ------------------------------------------------------------------------------------------------------
-- | Id  | Operation                           | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
-- ------------------------------------------------------------------------------------------------------
-- |   0 | SELECT STATEMENT                    |                |     1 |   869 |     6   (0)| 00:00:01 |
-- |*  1 |  TABLE ACCESS BY INDEX ROWID BATCHED| PURCHASEORDERS |     1 |   869 |     6   (0)| 00:00:01 |
-- |*  2 |   INDEX RANGE SCAN (MULTI VALUE)    | MVIUPPCODE     |     5 |       |     1   (0)| 00:00:01 |
-- ------------------------------------------------------------------------------------------------------
-- 
-- Predicate Information (identified by operation id):
-- ---------------------------------------------------
-- 
--    1 - filter(JSON_EXISTS2("PO"."DATA" /*+ LOB_BY_VALUE */  -- FORMAT OSON , '$?(@.PONumber ==
--               -- 25                         && exists(@.LineItems[*]?(
--               -- @.Part.UPCCode == 85391264828                                     && @.Quantity > 3)))' /*
--               -- json_path_str  $?((@.PONumber.number() == 25) &&
--               -- exists(@.LineItems[*]?((@.Part.UPCCode.number() == 85391264828) && (@.Quantity.number() >
-- 
-- -- PLAN_TABLE_OUTPUT
-- ___________________________________________________________________________________________________________
-- --              3))))  */  FALSE ON ERROR TYPE(LAX) )=1)
-- --   2 - access(JSON_QUERY("DATA" /*+ LOB_BY_VALUE */  FORMAT OSON ,
-- --              '$.LineItems[*].Part.UPCCode' RETURNING NUMBER ASIS  WITHOUT ARRAY WRAPPER ERROR ON ERROR
-- --              NULL ON EMPTY NULL ON MISMATCH TYPE(LAX)  MULTIVALUE)=85391264828)
-- 


------- Query Rewrite
-- Drop existing MV
BEGIN
  EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW JSON_PO_MV_PK';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -12003 THEN
      RAISE;
    END IF;
END;
/

--create the MV for query rewrite
-- This MV exposes the JSON paths used by the later JSON_EXISTS predicates as
-- relational columns. Oracle can rewrite eligible JSON queries to this MV.
BEGIN
  EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW mv_for_query_rewrite';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -12003 THEN
      RAISE;
    END IF;
END;
/
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
-- Sample output / notes:
-- ------------------------------------------------------------------------------------------------------
-- | Id  | Operation                           | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
-- ------------------------------------------------------------------------------------------------------
-- |   0 | SELECT STATEMENT                    |                |     1 |   869 |     6   (0)| 00:00:01 |
-- |*  1 |  TABLE ACCESS BY INDEX ROWID BATCHED| PURCHASEORDERS |     1 |   869 |     6   (0)| 00:00:01 |
-- |*  2 |   INDEX RANGE SCAN (MULTI VALUE)    | MVIUPPCODE     |     5 |       |     1   (0)| 00:00:01 |
-- ------------------------------------------------------------------------------------------------------
-- Predicate Information (identified by operation id):
-- ---------------------------------------------------
--   1 - filter(JSON_EXISTS2("PO"."DATA" /*+ LOB_BY_VALUE */  -- FORMAT OSON , '$?(@.PONumber ==
--           --    25                         && exists(@.LineItems[*]?(
--           --    @.Part.UPCCode == 85391264828                                     && @.Quantity > 3)))' /*
--           --    json_path_str  $?((@.PONumber.number() == 25) &&
--           --    exists(@.LineItems[*]?((@.Part.UPCCode.number() == 85391264828) && (@.Quantity.number() >
-- 



-- explain plan
explain plan for SELECT po.data FROM purchaseorders po
  WHERE json_exists(po.data,
                    '$?(@.User == "ABULL"
                        && exists(@.LineItems[*]?(
                                    @.Part.UPCCode == 85391628927
                                    && @.Quantity > 3)))');

 SELECT PLAN_TABLE_OUTPUT FROM TABLE(DBMS_XPLAN.DISPLAY());


-- Sample output / notes:
-- 
-- ------------------------------------------------------------------------------------------------------
-- | Id  | Operation                           | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
-- ------------------------------------------------------------------------------------------------------
-- |   0 | SELECT STATEMENT                    |                |     1 |   869 |     6   (0)| 00:00:01 |
-- |*  1 |  TABLE ACCESS BY INDEX ROWID BATCHED| PURCHASEORDERS |     1 |   869 |     6   (0)| 00:00:01 |
-- |*  2 |   INDEX RANGE SCAN (MULTI VALUE)    | MVIUPPCODE     |     5 |       |     1   (0)| 00:00:01 |
-- ------------------------------------------------------------------------------------------------------
-- 
-- Predicate Information (identified by operation id):
-- ---------------------------------------------------
-- 
--    1 - filter(JSON_EXISTS2("PO"."DATA" /*+ LOB_BY_VALUE */  -- FORMAT OSON , '$?(@.User ==
--               -- "ABULL"                         && exists(@.LineItems[*]?(
--               --  @.Part.UPCCode == 85391628927                                     && @.Quantity > 3)))' /*
--               -- json_path_str  $?((@.User.string() == "ABULL") &&
--               -- exists(@.LineItems[*]?((@.Part.UPCCode.number() == 85391628927) && (@.Quantity.number() >
--               -- 3))))  */  FALSE ON ERROR TYPE(LAX) )=1)
--    2 -- access(JSON_QUERY("DATA" /*+ LOB_BY_VALUE */  -- FORMAT OSON ,
--           --    '$.LineItems[*].Part.UPCCode' RETURNING NUMBER ASIS  WITHOUT ARRAY WRAPPER ERROR ON ERROR
--           --    NULL ON EMPTY NULL ON MISMATCH TYPE(LAX)  MULTIVALUE)=85391628927)
-- 


---
-- Create composite index on mv_for_query_rewrite
-- Drop the earlier demo multivalue index to compare access paths without it.
-- This composite index supports the USERID, UPC_CODE, and QUANTITY filters
-- that are projected from the embedded LineItems objects.
BEGIN
  EXECUTE IMMEDIATE 'DROP INDEX MVIUPPCODE';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -1418 THEN
      RAISE;
    END IF;
END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP INDEX MV_IDx';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -1418 THEN
      RAISE;
    END IF;
END;
/
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
-- Sample output / notes:
--  -----------------------------------------------------------------------------------------------------------------
-- | Id  | Operation                                | Name                 | Rows  | Bytes | Cost (%CPU)| Time     |
-- -----------------------------------------------------------------------------------------------------------------
-- |   0 | SELECT STATEMENT                         |                      |     1 |   903 |     5  (20)| 00:00:01 |
-- |   1 |  NESTED LOOPS                            |                      |     1 |   903 |     5  (20)| 00:00:01 |
-- |   2 |   SORT UNIQUE                            |                      |     1 |    33 |     3   (0)| 00:00:01 |
-- |   3 |    MAT_VIEW ACCESS BY INDEX ROWID BATCHED| MV_FOR_QUERY_REWRITE |     1 |    33 |     3   (0)| 00:00:01 |
-- |*  4 |     INDEX RANGE SCAN                     | MV_IDX               |     1 |       |     2   (0)| 00:00:01 |
-- |   5 |   TABLE ACCESS BY INDEX ROWID            | PURCHASEORDERS       |     1 |   870 |     1   (0)| 00:00:01 |
-- |*  6 |    INDEX UNIQUE SCAN                     | SYS_C008976          |     1 |       |     0   (0)| 00:00:01 |
-- -----------------------------------------------------------------------------------------------------------------
-- 
-- Predicate Information (identified by operation id):
-- ---------------------------------------------------
-- 
--    4 - access("SYS_JMV_1"."USERID"='ABULL' AND "SYS_JMV_1"."UPC_CODE"=85391628927 AND
--               "SYS_JMV_1"."QUANTITY">3 AND "SYS_JMV_1"."QUANTITY" IS NOT NULL)
--    6 - access("SYS_JMV_1"."RESID"=JSON_VALUE("DATA" /*+ LOB_BY_VALUE */ -- FORMAT OSON , '$._id' RETURNING
--    --           ANY ORA_RAWCOMPARE(2000) NO ARRAY ERROR ON ERROR TYPE(LAX) ))


-- Materialized view  aggregation
-- Pre-aggregate the extended price of every line item (quantity * unit price)
-- so purchase-order totals can be retrieved without reparsing each document.
-- This aggregate uses COMPLETE ON DEMAND refresh; it is not maintained on DML.
-- Totals are grouped by PONumber, which is assumed to identify an order uniquely.
BEGIN
  EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW mv_for_aggregation';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -12003 THEN
      RAISE;
    END IF;
END;
/
CREATE MATERIALIZED VIEW mv_for_aggregation
  BUILD IMMEDIATE
  REFRESH COMPLETE ON DEMAND
  AS SELECT jt.po_number, SUM(jt.quantity * jt.unitprice) AS total_amount
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

-- Sample output / notes:
-- 
-- -------------------------------------------------------------------------------------------
-- | Id  | Operation            | Name               | Rows  | Bytes | Cost (%CPU)| Time     |
-- -------------------------------------------------------------------------------------------
-- |   0 | SELECT STATEMENT     |                    | 10000 | 90000 |     8   (0)| 00:00:01 |
-- |   1 |  MAT_VIEW ACCESS FULL| MV_FOR_AGGREGATION | 10000 | 90000 |     8   (0)| 00:00:01 |
-- -------------------------------------------------------------------------------------------


-- Sample output / notes:
--   Search embeddedDocument query for the PURCHASEORDERS collection.
-- 
--   Every LineItems[*] object is materialized as one row. Thus predicates on
--   QUANTITY and UNIT_PRICE, and Oracle Text matching on DESCRIPTION, all apply
--   to the same embedded LineItems element.
-- 
--   Run as the owner of PURCHASEORDERS. The collection itself is not altered.

-- Drop the existing line-item search materialized view, if present...
BEGIN
  EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW purchaseorders_lineitems_mv';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -12003 THEN
      RAISE;
    END IF;
END;
/


--  Create or configure the Oracle Text wordlist...
DECLARE
  preference_count PLS_INTEGER;
BEGIN
  SELECT COUNT(*) INTO preference_count
  FROM ctx_user_preferences
  WHERE pre_name = 'PURCHASEORDERS_LI_WORDLIST';

  IF preference_count > 0 THEN
    ctx_ddl.drop_preference('purchaseorders_li_wordlist');
  END IF;
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
             NULL ON ERROR NULL ON EMPTY) as po_number,
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

-- Sample output / notes:
-- 
--    PO_NUMBER    ITEM_NUMBER DESCRIPTION                                    UNIT_PRICE    QUANTITY    RELEVANCE
-- ____________ ______________ ___________________________________________ _____________ ___________ ____________
--            2              4 Stardom                                             27.95           8            9
--           51              4 Roughnecks: Starship Troopers Chronicles            27.95           8            9
--          508              1 Stargate                                            27.95           8            9
--          927              4 Stargate & Moon 44                                  32.95           6            9
--         1047              2 Stardom                                             27.95           7            9
--         1259              1 Stargate                                            27.95           7            9
--         1392              3 Star Trek: First Contact                            27.95           5            9
--         1429              4 Stargate & Moon 44                                  32.95           8            9
--         1664              3 Stargate                                            27.95           7            9
--         1785              3 Stargate                                            27.95           7            9
--         1789              2 Starry Night                                        27.95           5            9
--         1825              5 Child Star: The Shirley Temple Story                27.95           9            9
--         1839              2 Star Trek: The Motion Picture                       32.95           7            9

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



-- Sample output / notes:
-- ---------------------------------------------------------------------------------------------------------------
-- | Id  | Operation                       | Name                        | Rows  | Bytes | Cost (%CPU)| Time     |
-- ---------------------------------------------------------------------------------------------------------------
-- |   0 | SELECT STATEMENT                |                             |    13 |   624 |    10  (10)| 00:00:01 |
-- |   1 |  SORT ORDER BY                  |                             |    13 |   624 |    10  (10)| 00:00:01 |
-- |*  2 |   MAT_VIEW ACCESS BY INDEX ROWID| PURCHASEORDERS_LINEITEMS_MV |    13 |   624 |     9   (0)| 00:00:01 |
-- |*  3 |    DOMAIN INDEX                 | PURCHASEORDERS_LI_TEXT_IDX  |       |       |     4   (0)| 00:00:01 |
-- ---------------------------------------------------------------------------------------------------------------
-- 
-- Predicate Information (identified by operation id):
-- ---------------------------------------------------
-- 
-- 
--    2 - filter("QUANTITY">=5 AND "UNIT_PRICE">=20)
--    3 - access("CTXSYS"."CONTAINS"("DESCRIPTION",'star%',1)>0)
-- 
-- 
-- 
-- 
prompt Refresh after loading or changing purchase orders:
prompt begin dbms_mview.refresh('PURCHASEORDERS_LINEITEMS_MV', 'C'); end;
prompt /


prompt Refresh aggregate totals after loading or changing purchase orders:
prompt begin dbms_mview.refresh('MV_FOR_AGGREGATION', 'C'); end;
prompt /
