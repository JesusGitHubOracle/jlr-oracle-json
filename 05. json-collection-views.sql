
---------------------------------------------------------------------------------
--1. Creating a Relational view with JSON_TABLE, PURCHASEORDER_V
--2. JSON COLLECTION VIEWS using JSON_TABLE  
-- 2.1 JSON COLLECTION VIEW : PURCHASEORDER_CV   
-- 2.2 JSON COLLECTION VIEW with AGGREGATE functions : PURCHASEORDER_TOT_PRC_CV 
-- 2.3 JSON COLLECTION VIEW with WINDOW function : PURCHASEORDER_AVG_PRC_CV  
---------------------------------------------------------------------------------
-- 1.Relational View using JSON_TABLE 
CREATE OR REPLACE VIEW PURCHASEORDER_V AS
      SELECT ponumber, requestor, special, address
      FROM PURCHASEORDERS,
          json_table (DATA, '$'
            COLUMNS (ponumber  number         PATH '$.PONumber',  
                     requestor varchar2(32)   PATH '$.Requestor',
                     special   varchar2(30)   PATH '$."Special Instructions"',
                     address    JSON  PATH '$.ShippingInstructions.Address')) jt         
;
-- Describing the Relational View PURCHASEORDER_V
DESC PURCHASEORDER_V;
/*
Name      Null? Type         
--------- ----- ------------ 
PONUMBER        NUMBER       
REQUESTOR       VARCHAR2(32) 
SPECIAL         VARCHAR2(10) 
ADDRESS         JSON   
*/

-- Querying the Relational View PURCHASEORDER_V

SELECT po_v.ponumber, po_v.REQUESTOR, po_v.SPECIAL, po_v.address.city FROM PURCHASEORDER_V po_v WHERE ponumber = 7;
PURCHASEORDER_V po_v WHERE po_v.ponumber = 7;
/*
  PONUMBER REQUESTOR      SPECIAL       CITY                     
___________ ______________ _____________ ________________________ 
          7 Vance Jones    Hand Carry    "South San Francisco"   */



--2.1 Creating and querying the JSON COLLECTION VIEW : PURCHASEORDER_CV
DROP  VIEW IF EXISTS PURCHASEORDER_CV;
CREATE JSON COLLECTION VIEW PURCHASEORDER_CV  AS 
  SELECT JSON {ponumber, requestor, special, itemnumber,quantity, itemdesc,unitprice, upccode}
      FROM PURCHASEORDERS,
          JSON_TABLE (DATA, '$'
            COLUMNS (ponumber  number         PATH '$.PONumber',
                     requestor varchar2(32)   PATH '$.Requestor',
                     special   varchar2(30)   PATH '$."Special Instructions"',
                     NESTED PATH '$.LineItems[*]'
                     COLUMNS
                     (  itemnumber number PATH '$.ItemNumber', 
                        quantity number PATH '$.Quantity',
                        NESTED PATH '$.Part[*]'
                        COLUMNS ( 
                        itemdesc varchar2(50) PATH '$.Description',
                        upccode  number PATH '$.UPCCode',
                        unitprice number PATH '$.UnitPrice')
                      )
                    ));

                    
--- Query the View                     
SELECT 
    JSON_VALUE(po.DATA, '$.requestor') AS requestor,
    JSON_VALUE(po.DATA, '$.ponumber') AS ponumber,
    JSON_VALUE(po.DATA, '$.itemnumber') AS itemnumber,
    JSON_VALUE(po.DATA, '$.itemdesc') AS itemdesc,
    JSON_VALUE(po.DATA, '$.unitprice') AS unitprice,
    JSON_VALUE(po.DATA, '$.quantity') AS quantity
FROM PURCHASEORDER_CV po 
WHERE JSON_VALUE(po.DATA, '$.ponumber') = 25
;

/*
REQUESTOR          PONUMBER    ITEMNUMBER    ITEMDESC                                  UNITPRICE    QUANTITY    
__________________ ___________ _____________ _________________________________________ ____________ ___________ 
"Timothy Gates"    25          1             "The Land Before Time: The Big Freeze"    27.95        2           
"Timothy Gates"    25          2             "Winning"                                 19.95        1           
"Timothy Gates"    25          3             "Falling Down"                            19.95        5         
*/

--2.2  Purchase Order total Price (SUM, GROUP BY aggregation functions):  PURCHASEORDER_TOT_PRC_CV
CREATE OR REPLACE JSON COLLECTION VIEW PURCHASEORDER_TOT_PRC_CV AS
    SELECT JSON {jt.ponumber, jt.requestor,  jt.total_price}
       FROM (
       SELECT  ROUND (SUM(unitprice * quantity),2)  total_price
       , ponumber
       , requestor
       FROM PURCHASEORDERS,
       JSON_TABLE(DATA, '$' error on error null on empty
       COLUMNS (ponumber  number         PATH '$.PONumber',
              requestor varchar2(32)   PATH '$.Requestor',
              special   varchar2(30)   PATH '$."Special Instructions"',
              NESTED PATH '$.LineItems[*]'
                     COLUMNS
                     ( itemnumber number PATH '$.ItemNumber',
                        quantity number PATH '$.Quantity',
                        NESTED PATH '$.Part[*]'
                        COLUMNS (
                        itemdesc varchar2(50) PATH '$.Description',
                        upccode  number PATH '$.UPCCode',
                        unitprice number PATH '$.UnitPrice')
                      )
                ))
        GROUP BY requestor, ponumber
        )jt
;
--2.3  Querying the JSON COLLECTION VIEW : PURCHASEORDER_TOT_PRC_CV
SELECT po.DATA.ponumber, po.DATA.requestor, po.DATA.total_price 
      FROM PURCHASEORDER_TOT_PRC_CV po
      WHERE po.DATA.ponumber=25;
                   
 /*
PONUMBER    REQUESTOR          TOTAL_PRICE    
___________ __________________ ______________ 
25          "Timothy Gates"    175.6          
 */

--2.3  Purchase Order items average  price   (AVG, WINDOW function):  PURCHASEORDER_AVG_PRC_CV 
CREATE OR REPLACE JSON COLLECTION VIEW PURCHASEORDER_AVG_PRC_CV AS
    SELECT JSON {
       jt.ponumber,
       jt.itemnumber,
       jt.itemdesc,
       jt.quantity,
       jt.unitprice,
       jt.total_item_price,
       jt.average_total_item_price}
    FROM (
    SELECT 
           ponumber, 
           itemnumber,
           itemdesc,
           quantity,
           unitprice,  
          ROUND (unitprice * quantity,2) total_item_price,
          ROUND (avg(unitprice * quantity) over (partition by ponumber),2)  average_total_item_price -- average per purchase order (partitioned by ponumber)
          FROM PURCHASEORDERS, 
                JSON_TABLE(
                    DATA, '$'
                    error on error null on empty
                    COLUMNS (
                        ponumber  number         PATH '$.PONumber',
                        requestor varchar2(32)   PATH '$.Requestor',
                        special   varchar2(30)   PATH '$."Special Instructions"',
                        NESTED PATH '$.LineItems[*]'
                            COLUMNS (
                                itemnumber number PATH '$.ItemNumber',
                                  itemdesc varchar2(50) PATH '$.Description',
                                  quantity number PATH '$.Quantity',
                                  upccode  number PATH '$.UPCCode',
                                  unitprice number PATH '$.UnitPrice')
                                    )
                            )
                
          ) jt
;

--  Querying the JSON COLLECTION VIEW : PURCHASEORDER_AVG_PRC_CV
SELECT po.DATA.ponumber,
       po.DATA.itemnumber,
       po.DATA.itemdesc,
       po.DATA.quantity,
       po.DATA.unitprice,
       po.DATA.total_item_price,
       po.DATA.average_total_item_price 
 FROM PURCHASEORDER_AVG_PRC_CV po
 WHERE po.DATA.ponumber=25
;
 
/*

PONUMBER    ITEMNUMBER    ITEMDESC                                  QUANTITY    UNITPRICE    TOTAL_ITEM_PRICE    AVERAGE_TOTAL_ITEM_PRICE    
___________ _____________ _________________________________________ ___________ ____________ ___________________ ________________________ 
25          1             "The Land Before Time: The Big Freeze"    2           27.95        55.9                58.53                 
25          2             "Winning"                                 1           19.95        19.95               58.53                 
25          3             "Falling Down"                            5           19.95        99.75               58.53                 
*/


