/*
Examples of SQL/JSON core operators in Oracle AI Database
| Operator     | Purpose                                                          |
| --------     | -----------------------------------------------------------------|
| `JSON_VALUE` | Extract one scalar value, such as a number or string.            |
| `JSON_EXISTS`| Test whether JSON data or a path match exists; used in `WHERE`.  |
| `JSON_QUERY` | Extract a JSON object or array fragment.                         |
| `JSON_TABLE` | Project JSON into relational rows and columns.                   |
*/


-------------------------------------------------------------------------------------------------------
--  Extracting fields from first three purchase orders using JSON_VALUE
-------------------------------------------------------------------------------------------------------
SELECT JSON_VALUE (
     DATA, 
     '$._id') "_id",
       JSON_VALUE (
          DATA, 
          '$.Reference') "REFERENCE",
       JSON_VALUE (
          DATA, 
          '$.Requestor') "REQUESTOR"
  FROM PURCHASEORDERS
 FETCH FIRST 3 ROWS ONLY;

/*
_id                         REFERENCE            REQUESTOR          
___________________________ ____________________ __________________ 
67be06a3a41b42248290f032    HBLOOM-20141104      Harrison Bloom     
67be06a3a41b42248290f034    CDAVIES-20141114     Curtis Davies      
67be06a3a41b42248290f039    VPATABAL-20141111    Valli Pataballa   
*/


---------------------------------------------------------------------------------------------------------
--  Filtering purchase orders by PONumber
--  the queries below uses JSON_EXISTS with bind variables ($V1, $V2) in a JSON path expression .
--  Filter purchase orders by PONumber 25
---------------------------------------------------------------------------------------------------------


SELECT JSON_SERIALIZE(DATA PRETTY ORDERED) PONUM_25
    FROM PURCHASEORDERS 
    WHERE JSON_EXISTS(
     DATA,
      '$?(@.PONumber == $V1)' 
       PASSING '25' AS "V1");
 
/* 
{                                                                  
  "_id" : "67be06a1a41b42248290c974",                              
  "CostCenter" : "A50",                                            
  "PONumber" : 25,                                                 
  "Reference" : "TGATES-20140511",                                 
  "Requestor" : "Timothy Gates",                                   
  "Special Instructions" : "Priority Overnight",                   
  "User" : "TGATES",                                               
  "ShippingInstructions" :                                         
  {                                                                
    "name" : "Timothy Gates",                                      
    "Address" :                                                    
    {                                                              
      "city" : "South San Francisco",                              
      "country" : "United States of America",                      
      "state" : "CA",                                              
      "street" : "200 Sporting Green",                             
      "zipCode" : 99236                                            
    },                                                             
    "Phone" :                                                      
    [                                                              
      {                                                            
        "number" : "978-555-2039",                                 
        "type" : "Office"                                          
      }                                                            
    ]                                                              
  },                                                               
  "LineItems" :                                                    
  [                                                                
    {                                                              
      "ItemNumber" : 1,                                            
      "Quantity" : 2,                                              
      "Part" :                                                     
      {                                                            
        "Description" : "The Land Before Time: The Big Freeze",    
        "UPCCode" : 25192126529,                                   
        "UnitPrice" : 27.95                                        
      }                                                            
    },                                                             
    {                                                              
      "ItemNumber" : 2,                                            
      "Quantity" : 1,                                              
      "Part" :                                                     
      {                                                            
        "Description" : "Winning",                                 
        "UPCCode" : 25192052620,                                   
        "UnitPrice" : 19.95                                        
      }                                                            
    },                                                             
    {                                                              
      "ItemNumber" : 3,                                            
      "Quantity" : 5,                                              
      "Part" :                                                     
      {                                                            
        "Description" : "Falling Down",                            
        "UPCCode" : 85391264828,                                   
        "UnitPrice" : 19.95                                        
      }                                                            
    }                                                              
  ]                                                                
}               
*/
 
-----------------------------------------------------------------------------------------------------------
--- Filtering purchase orders by "_id"
-----------------------------------------------------------------------------------------------------------

SELECT JSON_SERIALIZE (
    DATA PRETTY)
    FROM PURCHASEORDERS 
    WHERE JSON_EXISTS(
     DATA, 
     '$?(@._id == $V1)'
    PASSING '67be06a1a41b42248290c974' AS "V1");
 
/*
{                                                                  
  "_id" : "67be06a1a41b42248290c974",                              
  "PONumber" : 25,                                                 
  "Reference" : "TGATES-20140511",                                 
  "Requestor" : "Timothy Gates",                                   
  "User" : "TGATES",                                               
  "CostCenter" : "A50",                                            
  "ShippingInstructions" :                                         
  {                                                                
    "name" : "Timothy Gates",                                      
  ......
*/

-----------------------------------------------------------------------------------------------------------
--- Filtering purchase orders by values from JSON arrays
-- The query below counts the numberpurchase orders with line-items UPCCode of 85391628927 
-----------------------------------------------------------------------------------------------------------

SELECT COUNT(*) LineItems FROM PURCHASEORDERS 
  WHERE JSON_EXISTS (
     DATA,
     '$.LineItems.Part?(@.UPCCode == $V1)'
     PASSING '85391264828' AS "V1");

/*
LINEITEMS                                                                           
__________
        5
*/                    
                    
-------------------------------------------------------------------------------------------------------------
-- The query below counts the number of purchase orders with LineItems price less than 19 and greater than 14
-- Note: The field UnitPrice is stored as double in the JSON document, which corresonds to SQL BINARY_DOUBLE.
------------------------------------------------------------------------------------------------------------
 
SELECT COUNT(*)
FROM PURCHASEORDERS
WHERE JSON_EXISTS(
  DATA,
  '$.LineItems.Part?(
     @.UnitPrice < $V1
     && @.UnitPrice > $V2
   )'
  PASSING
    CAST(19 AS BINARY_DOUBLE) AS "V1",
    CAST(14 AS BINARY_DOUBLE) AS "V2"
);

 
-----------------------------------------------------------------------------------------------------------
-- Extracting Orders allowing Partial Shipments - Using Boolean DATA type (requires Oracle 26ai or later) 
-----------------------------------------------------------------------------------------------------------
SELECT JSON_VALUE(
     DATA,
     '$.Reference') AS PARTIAL_SHIP 
     FROM PURCHASEORDERS 
     WHERE JSON_VALUE (
          DATA, '$.AllowPartialShipment'
          RETURNING BOOLEAN);

/*
PARTIAL_SHIP
--------------     
ABULL-20140421
*/


-------------------------------------------------------------------------------------------------------
-- Counting purchase orders with Shipping Instructions to the state of California (CA)  
-------------------------------------------------------------------------------------------------------
SELECT count(*) AS PO_CA_COUNT 
     FROM PURCHASEORDERS 
     WHERE JSON_EXISTS(
        DATA,
        '$.ShippingInstructions?(@.Address.state == $V1)' 
         PASSING 'CA' AS "V1");

/* 4283 */

-------------------------------------------------------------------------------------------------------
-- Counting purchase orders with Shipping Instructions addressed to 'Timothy Gates'
-------------------------------------------------------------------------------------------------------
SELECT count(*) AS PO_TG_COUNT
      FROM PURCHASEORDERS 
      WHERE JSON_EXISTS(
          DATA, 
          '$.ShippingInstructions?(@.name == $V1)'
          PASSING 'Timothy Gates' AS "V1");

/*89*/

-------------------------------------------------------------------------------------------------------
--  Extracting the nested JSON object, rather than a single scalar with JSON_QUERY.
-------------------------------------------------------------------------------------------------------
SELECT JSON_SERIALIZE(
         JSON_QUERY(DATA, '$.ShippingInstructions')
         PRETTY
       ) AS po_ship_1000
FROM PURCHASEORDERS
WHERE JSON_VALUE(DATA, '$.PONumber' RETURNING BINARY_DOUBLE) = 1000;

/*
{
  "name" : "Charles Johnson",
  "Address" :
  {
    "street" : "Magdalen Centre, The Isis Science Park",
    "city" : "Oxford",
    "county" : "Oxon.",
    "postcode" : "OX9 9ZB",
    "country" : "United Kingdom"
  },
  "Phone" :
  [
    {
      "type" : "Office",
      "number" : "66-555-3120"
    }
  ]
}
*/

-------------------------------------------------------------------------------------------------------
-- Converting selected fields from each JSON purchase-order document into relational columns using JSON_TABLE.
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

-- retrieve the relational columns from the CTE
SELECT ponumber, requestor, special, address FROM  po_cte;

/*
  PONUMBER REQUESTOR            SPECIAL               ADDRESS                                                                                                                                 
___________ ____________________ _____________________ _______________________________________________________________________________________________________________________________________ 
       5709 Allan McEwen         Surface Mail          {"street":"Magdalen Centre, The Isis Science Park","city":"Oxford","county":"Oxon.","postcode":"OX9 9ZB","country":"United Kingdom"}    
       5717 Jason Mallin         Hand Carry            {"street":"200 Sporting Green","city":"South San Francisco","state":"CA","zipCode":99236,"country":"United States of America"}          
       5718 Alyssa Hutton        Counter to Counter    {"street":"Magdalen Centre, The Isis Science Park","city":"Oxford","county":"Oxon.","postcode":"OX9 9ZB","country":"United Kingdom"}    
       5425 Trenna Rajs          Courier               {"street":"200 Sporting Green","city":"South San Francisco","state":"CA","zipCode":99236,"country":"United States of America"}          
       5426 Trenna Rajs          Surface Mail          {"street":"200 Sporting Green","city":"South San Francisco","state":"CA","zipCode":99236,"country":"United States of America"}          
       5427 Trenna Rajs          Next Day Air          {"street":"200 Sporting Green","city":"South San Francisco","state":"CA","zipCode":99236,"country":"United States of America"}          
       5434 Patrick Sully        Courier               {"street":"Magdalen Centre, The Isis Science Park","city":"Oxford","county":"Oxon.","postcode":"OX9 9ZB","country":"United Kingdom"}    
       5438 Stephen Stiles       Counter to Counter    {"street":"200 Sporting Green","city":"South San Francisco","state":"CA","zipCode":99236,"country":"United States of America"}          
       5439 Stephen Stiles       Ground                {"street":"200 Sporting Green","city":"South San Francisco","state":"CA","zipCode":99236,"country":"United States of America"}          
       5440 Vance Jones          Hand Carry            {"street":"200 Sporting Green","city":"South San Francisco","state":"CA","zipCode":99236,"country":"United States of America"}          
       5574 Timothy Gates        Counter to Counter    {"street":"200 Sporting Green","city":"South San Francisco","state":"CA","zipCode":99236,"country":"United States of America"}          
       5578 Susan Mavris         Surface Mail          {"street":"8204 Washington St","city":"London","county":"","postcode":"EC2M 2RB","country":"United Kingdom"}                            
       5580 Samuel McCain        COD                   {"street":"200 Sporting Green","city":"South San Francisco","state":"CA","zipCode":99236,"country":"United States of America"}          
       5581 TJ Olson             Counter to Counter    {"street":"200 Sporting Green","city":"South San Francisco","state":"CA","zipCode":99236,"country":"United States of America"}          
       5582 Trenna Rajs          Hand Carry            {"street":"200 Sporting Green","city":"South San Francisco","state":"CA","zipCode":99236,"country":"United States of America"}          
       5583 Steven King          Courier               {"street":"2004 Blacksmiths Court","city":"Seattle","state":"WA","zipCode":98199,"country":"United States of America"}                  
       5586 Tayler Fox           Ground                {"street":"Magdalen Centre, The Isis Science Park","city":"Oxford","county":"Oxon.","postcode":"OX9 9ZB","country":"United Kingdom"}    
       5590 TJ Olson             Surface Mail          {"street":"200 Sporting Green","city":"South San Francisco","state":"CA","zipCode":99236,"country":"United States of America"}          
       5283 Samuel McCain        Priority Overnight    {"street":"200 Sporting Green","city":"South San Francisco","state":"CA","zipCode":99236,"country":"United States of America"}          
       5284 Sarath Sewall        Courier               {"street":"Magdalen Centre, The Isis Science Park","city":"Oxford","county":"Oxon.","postcode":"OX9 9ZB","country":"United Kingdom"}    
       5297 Nanette Cambrault    Priority Overnight    {"street":"Magdalen Centre, The Isis Science Park","city":"Oxford","county":"Oxon.","postcode":"OX9 9ZB","country":"United Kingdom"}    
       5300 Karen Colmenares     Surface Mail          {"street":"2004 Blacksmiths Court","city":"Seattle","state":"WA","zipCode":98199,"country":"United States of America"}                  
       5303 Steven King          Priority Overnight    {"street":"2004 Blacksmiths Court","city":"Seattle","state":"WA","zipCode":98199,"country":"United States of America"}                  
       5309 Susan Mavris         COD                   {"street":"8204 Washington St","city":"London","county":"","postcode":"EC2M 2RB","country":"United Kingdom"}                            
       5310 Ki Gee               COD                   {"street":"200 Sporting Green","city":"South San Francisco","state":"CA","zipCode":99236,"country":"United States of America"}          
       5720 Alexander Khoo       Hand Carry            {"street":"2004 Blacksmiths Court","city":"Seattle","state":"WA","zipCode":98199,"country":"United States of America"}                  

  */
