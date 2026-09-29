
--------------------------------------------------------------------------------------------------------------
-- ORacle JSON INDEXING: 
-- Unique Index
-- Composite Index  
-- Multivalue Index 
-- Partial Index
-- JSON Search Index
------------------------------------------ INDEXING --------------------------------------------------------------



-----------------------------------------------------------------------------------------------------------
-- Unique index :Extracts the PONumber JSON property as a number and creates a unique index.
-----------------------------------------------------------------------------------------------------------

DROP INDEX IF EXISTS po_num_idx;

CREATE UNIQUE INDEX po_num_idx
ON PURCHASEORDERS po
  (po.data.PONumber.number());

EXPLAIN PLAN FOR 
  SELECT DATA FROM PURCHASEORDERS p
  WHERE p.data.PONumber.number() = 10000;
SELECT PLAN_TABLE_OUTPUT FROM TABLE(DBMS_XPLAN.DISPLAY())
/* 
----------------------------------------------------------------------------------------------    
| Id  | Operation                   | Name           | Rows  | Bytes | Cost (%CPU)| Time     |    
----------------------------------------------------------------------------------------------    
|   0 | SELECT STATEMENT            |                |     1 |   871 |     2   (0)| 00:00:01 |    
|   1 |  TABLE ACCESS BY INDEX ROWID| PURCHASEORDERS |     1 |   871 |     2   (0)| 00:00:01 |    
|*  2 |   INDEX UNIQUE SCAN         | PO_NUM_IDX     |     1 |       |     1   (0)| 00:00:01 |    
----------------------------------------------------------------------------------------------    
                                                                                                  
Predicate Information (identified by operation id):                                               
---------------------------------------------------                                               
                                                                                                  
   2 - access(JSON_VALUE("DATA" /*+ LOB_BY_VALUE */ -- FORMAT OSON ,                                
  --            '$.PONumber.number()' RETURNING NUMBER NULL ON ERROR TYPE(LAX) )=10000)

*/            

-----------------------------------------------------------------------------------------------------------------------------
-- Composite index:  Extracts User and CostCenter JSON properties as Strings and stores them together in one composite index.
-- It is non-unique, so many purchase orders can share the same user and cost center
-- po.data."User".string() and po.data."User".string() have a default SQL return type of VARCHAR2(4000)—up to 4,000 bytes.
------------------------------------------------------------------------------------------------------------------------------

DROP INDEX IF EXISTS user_cost_ctr_idx;

CREATE INDEX user_cost_ctr_idx
ON PURCHASEORDERS po (
  po.data."User".string(),
  po.data.CostCenter.string()
);


EXPLAIN PLAN FOR
SELECT data
FROM PURCHASEORDERS p
WHERE p.data."User".string() = 'ABULL'
  AND p.data.CostCenter.string() = 'A50';

SELECT PLAN_TABLE_OUTPUT
FROM TABLE(DBMS_XPLAN.DISPLAY());

/*
----------------------------------------------------------------------------------------------------------------------------------------        
| Id  | Operation                             | Name              | Rows  | Bytes | Cost (%CPU)| Time     |    TQ  |IN-OUT| PQ Distrib |        
----------------------------------------------------------------------------------------------------------------------------------------        
|   0 | SELECT STATEMENT                      |                   |    72 | 67464 |    61   (0)| 00:00:01 |        |      |            |        
|   1 |  PX COORDINATOR                       |                   |       |       |            |          |        |      |            |        
|   2 |   PX SEND QC (RANDOM)                 | :TQ10001          |    72 | 67464 |    61   (0)| 00:00:01 |  Q1,01 | P->S | QC (RAND)  |        
|   3 |    TABLE ACCESS BY INDEX ROWID BATCHED| PURCHASEORDERS    |    72 | 67464 |    61   (0)| 00:00:01 |  Q1,01 | PCWP |            |        
|   4 |     BUFFER SORT                       |                   |       |       |            |          |  Q1,01 | PCWC |            |        
|   5 |      PX RECEIVE                       |                   |    85 |       |     1   (0)| 00:00:01 |  Q1,01 | PCWP |            |        
|   6 |       PX SEND HASH (BLOCK ADDRESS)    | :TQ10000          |    85 |       |     1   (0)| 00:00:01 |  Q1,00 | S->P | HASH (BLOCK|        
|   7 |        PX SELECTOR                    |                   |       |       |            |          |  Q1,00 | SCWC |            |        
|*  8 |         INDEX RANGE SCAN              | USER_COST_CTR_IDX |    85 |       |     1   (0)| 00:00:01 |  Q1,00 | SCWP |            |        
----------------------------------------------------------------------------------------------------------------------------------------        
                                                                                                                                                
Predicate Information (identified by operation id):                                                                                             
---------------------------------------------------                                                                                             
                                                                                                                                                
   8 - access(JSON_VALUE("DATA" /*+ LOB_BY_VALUE */ -- FORMAT OSON , '$."User".string()' RETURNING VARCHAR2(4000) NULL ON ERROR                   
    --          TYPE(LAX) )='ABULL' AND JSON_VALUE("DATA" /*+ LOB_BY_VALUE */  FORMAT OSON , '$.CostCenter.string()' RETURNING VARCHAR2(4000)     
    --          NULL ON ERROR TYPE(LAX) )='A50')   

*/



-----------------------------------------------------------------------------------------------------------------------------
-- Same as above, Composite Index creation using JSON_VALUE
-- It indexes:  The JSON User value as text up to 20 characters AND The JSON CostCenter value as text up to 6 characters.
----------------------------------------------------------------------------------------------------------------------------

DROP INDEX IF EXISTS user_cost_ctr_idx;
CREATE INDEX user_cost_ctr_idx ON
  PURCHASEORDERS (json_value(data, '$.User' RETURNING VARCHAR2(20)),
                  json_value(data, '$.CostCenter' RETURNING VARCHAR2(6)));




--------------------------------------------------------------------------------------------------------------------------------------------
-- Multivalue index is specifically intended for JSON scalars that can occur multiple times in an array.
-- Create a multivalue index for every LineItems[*].Part.UPCCode value.
-- The multivalue index can speed this up by indexing each line item’s UPC code separately.
--------------------------------------------------------------------------------------------------------------------------------------------

DROP INDEX IF EXISTS mviuppcode;

CREATE MULTIVALUE INDEX mviuppcode
ON purchaseorders (
  JSON_TABLE(
    data,
    '$'
    ERROR ON ERROR
    NULL ON EMPTY
    NULL ON MISMATCH
    COLUMNS (
      NESTED PATH '$.LineItems[*]'
      COLUMNS (
        upccode NUMBER PATH '$.Part.UPCCode'
      )
    )
  )
);


--------------------------------------------------------------------------------------------------------------------------------------------
-- querying the multivalue index:  Extracts the all json data for a specific UPC code inside the array
--------------------------------------------------------------------------------------------------------------------------------------------
 
EXPLAIN PLAN FOR 
SELECT data
FROM PURCHASEORDERS
WHERE JSON_EXISTS(
  data,
  '$.LineItems.Part?(@.UPCCode.number() == $V1)'
  PASSING 85391264828 AS "V1"
);
SELECT PLAN_TABLE_OUTPUT FROM TABLE(DBMS_XPLAN.DISPLAY());
 

 /*
 -------------------------------------------------------------------------------------------------------------------------------------    
| Id  | Operation                             | Name           | Rows  | Bytes | Cost (%CPU)| Time     |    TQ  |IN-OUT| PQ Distrib |    
-------------------------------------------------------------------------------------------------------------------------------------    
|   0 | SELECT STATEMENT                      |                |     2 |  1742 |     6   (0)| 00:00:01 |        |      |            |    
|   1 |  PX COORDINATOR                       |                |       |       |            |          |        |      |            |    
|   2 |   PX SEND QC (RANDOM)                 | :TQ10001       |     2 |  1742 |     6   (0)| 00:00:01 |  Q1,01 | P->S | QC (RAND)  |    
|   3 |    TABLE ACCESS BY INDEX ROWID BATCHED| PURCHASEORDERS |     2 |  1742 |     6   (0)| 00:00:01 |  Q1,01 | PCWP |            |    
|   4 |     BUFFER SORT                       |                |       |       |            |          |  Q1,01 | PCWC |            |    
|   5 |      PX RECEIVE                       |                |     5 |       |     1   (0)| 00:00:01 |  Q1,01 | PCWP |            |    
|   6 |       PX SEND HASH (BLOCK ADDRESS)    | :TQ10000       |     5 |       |     1   (0)| 00:00:01 |  Q1,00 | S->P | HASH (BLOCK|    
|   7 |        PX SELECTOR                    |                |       |       |            |          |  Q1,00 | SCWC |            |    
|*  8 |         INDEX RANGE SCAN (MULTI VALUE)| MVIUPPCODE     |     5 |       |     1   (0)| 00:00:01 |  Q1,00 | SCWP |            |    
-------------------------------------------------------------------------------------------------------------------------------------    
                                                                                                                                         
Predicate Information (identified by operation id):                                                                                      
---------------------------------------------------                                                                                      
                                                                                                                                         
   8 - access(JSON_QUERY("DATA" /*+ LOB_BY_VALUE */ -- FORMAT OSON , '$.LineItems[*].Part.UPCCode' RETURNING NUMBER ASIS                   
            --  WITHOUT ARRAY WRAPPER ERROR ON ERROR NULL ON EMPTY NULL ON MISMATCH TYPE(LAX)  MULTIVALUE)=85391264828)  
 
 
 */





------------------------------------------------------------------------------------------------------------------------
-- Alternative sytanx: Creating Multivalue index on nested array using JSON_TABLE
--------------------------------------------------------------------------------------------------------------------------------------------

DROP INDEX mvi_uppcode_JT;
CREATE MULTIVALUE INDEX mviuppcode ON PURCHASEORDERS
  (JSON_TABLE(
    DATA,  '$' error on error null on empty NULL ON MISMATCH
    COLUMNS (NESTED PATH '$.LineItems[*]'
            COLUMNS (NESTED PATH '$.Part'
                    COLUMNS (upccode NUMBER PATH '$.UPCCode'
                    )
            )
    )
));



--------------------------------------------------------------------------------------------------------------------------------------------
-- Partial Index: It creates a partial function-based index containing only purchase orders whose ZIP code is 99236.
--------------------------------------------------------------------------------------------------------------------------------------------
DROP INDEX IF EXISTS par_postcode_idx;

CREATE INDEX par_postcode_idx ON purchaseorders (
  CASE
    WHEN JSON_VALUE(
           data,
           '$.ShippingInstructions.Address.postcode'
           RETURNING VARCHAR2(20)
           ERROR ON ERROR
           NULL ON EMPTY
         ) = 'OX9 9ZB'
    THEN 'OX9 9ZB'
  END
);

--
EXPLAIN PLAN FOR  
SELECT data
FROM purchaseorders
WHERE CASE
        WHEN JSON_VALUE(
               data,
               '$.ShippingInstructions.Address.postcode'
               RETURNING VARCHAR2(20)
               ERROR ON ERROR
               NULL ON EMPTY
             ) = 'OX9 9ZB'
        THEN 'OX9 9ZB'
      END = 'OX9 9ZB';
SELECT PLAN_TABLE_OUTPUT FROM TABLE(DBMS_XPLAN.DISPLAY());
 

--------------------------------------------------------------------------------------------------------------------------------------------
-- JSON search index. It is designed for Full Text Search.
-- MAINTENANCE AUTO means Oracle updates the index asynchronously in the background as documents change; you do not manually synchronize it.
-- GIT repo : 
-- oracle blog: https://blogs.oracle.com/coretec/json-full-text-search-with-oracle-ai-database-26ai
--------------------------------------------------------------------------------------------------------------------------------------------

DROP INDEX IF EXISTS po_search_idx;
CREATE SEARCH INDEX po_search_idx ON PURCHASEORDERS (DATA)
  FOR JSON PARAMETERS ('MAINTENANCE AUTO');









 

 



 
