-------------------------------------------------------------------------------------------------------
--  Querying JSON COLLECTION TABLE PURCHASEORDERS :  JSON_VALUE, JSON_EXISTS, JSON_QUERY
-------------------------------------------------------------------------------------------------------
-- JSON_VALUE Extracting three fields from first three POs 
SELECT JSON_VALUE (DATA, '$._id') "_id",
       JSON_VALUE (DATA, '$.Reference') "REFERENCE",
       JSON_VALUE (DATA, '$.Requestor') "REQUESTOR"
  FROM PURCHASEORDERS
 WHERE ROWNUM < 4;

 
-- The following query uses JSON_EXISTS with a bind variable ($V1) in a JSON path expression to filter purchase orders by PONumber.
SELECT JSON_SERIALIZE(DATA PRETTY ORDERED) PONUM_25
    FROM PURCHASEORDERS 
    WHERE JSON_EXISTS(DATA, '$?(@.PONumber == $V1)'  PASSING '25' AS "V1");
 
 
-- JSON_EXISTS. Query by "_id"
SELECT JSON_SERIALIZE (DATA PRETTY)
    FROM PURCHASEORDERS 
    WHERE JSON_EXISTS(DATA, '$?(@._id == $V1)'
    PASSING '69012390d4160cd3c42f7059' AS "V1")
;
 
-- JSON_VALUE. Extracting three POs references
SELECT JSON_VALUE (DATA, '$.Reference') "PO Reference"
       FROM PURCHASEORDERS where ROWNUM < 4;


--JSON_EXISTS. Extracting  LineItems with UPCCode = 85391628927
SELECT JSON_SERIALIZE(DATA pretty) LineItems FROM PURCHASEORDERS 
  WHERE JSON_EXISTS (DATA,'$.LineItems.Part?(@.UPCCode == $V1)'
                    PASSING '85391628927' AS "V1");
                    
-------------------------------------------------------------------------------------------------------
--- Extracting LineItems with unit price less than 19
-------------------------------------------------------------------------------------------------------
SELECT JSON_SERIALIZE(DATA PRETTY) FROM PURCHASEORDERS 
   WHERE JSON_EXISTS(DATA,  '$.LineItems.Part?(@.UnitPrice < $V1)'
                    PASSING '19' AS "V1");
-------------------------------------------------------------------------------------------------------
--- Extracting Purchase Order 25
-------------------------------------------------------------------------------------------------------
SELECT JSON_SERIALIZE(DATA PRETTY) AS PONUM_25 FROM PURCHASEORDERS
     WHERE JSON_EXISTS(DATA, '$?(@.PONumber == $V1)'
       PASSING '25' AS "V1" ); 
-------------------------------------------------------------------------------------------------------
-- Extracting Orders allowing Partial Shipments - Boolean DATA type 
-------------------------------------------------------------------------------------------------------
SELECT JSON_SERIALIZE(DATA PRETTY) AS PARTIAL_SHIP 
     FROM PURCHASEORDERS 
     WHERE JSON_VALUE (DATA, '$.AllowPartialShipment'
                  RETURNING BOOLEAN);
-------------------------------------------------------------------------------------------------------
-- Shipping instructions :  state CA
-------------------------------------------------------------------------------------------------------
SELECT JSON_SERIALIZE(DATA PRETTY) AS PO_CA 
     FROM PURCHASEORDERS 
     WHERE JSON_EXISTS(DATA,'$.ShippingInstructions?(@.Address.state == $V1)' 
                    PASSING 'CA' AS "V1");
-------------------------------------------------------------------------------------------------------
-- Shipping instructions :  name Timothy Gates
-------------------------------------------------------------------------------------------------------
SELECT JSON_SERIALIZE(DATA PRETTY) AS PO_TG
      FROM PURCHASEORDERS 
      WHERE JSON_EXISTS( DATA, '$.ShippingInstructions?(@.name == $V1)'
                                   PASSING 'Timothy Gates' AS "V1");
-------------------------------------------------------------------------------------------------------
-- JSON Query
-------------------------------------------------------------------------------------------------------
SELECT JSON_SERIALIZE(JSON_QUERY(DATA,'$.ShippingInstructions') PRETTY) as PO_SHIP_1000
     FROM PURCHASEORDERS
     where JSON_VALUE(DATA,'$.PONumber' returning number)=1000;

-------------------------------------------------------------------------------------------------------
-- JSON Table Function using a CTE 
-------------------------------------------------------------------------------------------------------

WITH po_cte AS 
          (SELECT ponumber, requestor, special, address
          FROM PURCHASEORDERS,
             JSON_TABLE (DATA, '$'
                COLUMNS (ponumber  number         PATH '$.PONumber',
                         requestor varchar2(32)   PATH '$.Requestor',
                         special   varchar2(32)   PATH '$."Special Instructions"',
                         address    JSON  PATH '$.ShippingInstructions.Address')) jt
            )
SELECT ponumber, requestor, special, address FROM  po_cte;


