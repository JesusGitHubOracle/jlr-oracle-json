-- as ADMIN, add necessary toles
grant select on "V$SQL" to SALES_HISTORY;
grant select on "V$SQL_MONITOR" to SALES_HISTORY;
grant advisor to SALES_HISTORY; 
grant execute on dbms_sql_monitor to SALES_HISTORY;

-- Add the MONITOR hint from mongosh
-- mongosh> db.purchaseorders.find({$match : {PONumber : 25}}).hint({$native : "MONITOR"});

-- Determine the SQL_ID
/* mongosh> db.aggregate([{$sql:`
       select sql_fulltext, sql_id 
       from v$sql 
       where sql_text like '%MONITOR%' and
             sql_text not like '%v$sql%'
       order by last_active_time desc
       fetch first 1 rows only
   `}]);
 [
   {
     SQL_FULLTEXT: '...',
     SQL_ID: '2ntka96q489ws'
   }
 ]
*/
-- Generate the report
/*mongosh> var html = 
   db.aggregate([{$sql:`
     select dbms_sql_monitor.report_sql_monitor(
       sql_id => '0azbznb0c0ynz',
       report_level => 'ALL',
       type => 'ACTIVE'
     ) as "html"
     from dual
   `}]).toArray()[0].html;

mongosh> require('fs').writeFileSync('/Users/jlrobles/out.html', html);
*/


-------------------------------------------------------------------------------
---------------------------- DBMS_SQLDIAG --------------------------------------
--------------------------------------------------------------------------------
-- dbms_sqldiag.report_sql 

set feedback on sql_id
SELECT  /*+ MONITOR */  data FROM purchaseorders
  WHERE json_value(data, '$.User') = 'ABULL'
    AND json_value(data, '$.CostCenter') = 'A50';

/* 
{"_id":"66cd794eca37168420771fea","CostCenter":"A50","PONumber":8358,"Reference":"ABULL-20140509","Requestor":"Alexis Bull","Special Instructions":"Ground","User":"ABULL","ShippingInstructions":{"name":"Alexis Bull","Address":{"city":"South San Francisco","country":"United States of America","state":"CA","street":"200 Sporting Green","zipCode":99236},"Phone":[{"number":"70-555-4236","type":"Office"}]},"LineItems":[{"ItemNumber":1,"Quantity":9,"Part":{"Description":"30th Anniversary of Rock 'N Roll All Star Jam With Bo Diddley","UPCCode":13023010192,"UnitPrice":19.95}},{"ItemNumber":2,"Quantity":4,"Part":{"Description":"All Quiet on the Western Front","UPCCode":25192051029,"UnitPrice":19.95}},{"ItemNumber":3,"Quantity":8,"Part":{"Description":"Malice","UPCCode":27616854780,"UnitPrice":19.95}},{"ItemNumber":4,"Quantity":5,"Part":{"Description":"There's No Business Like Show Business","UPCCode":24543014454,"UnitPrice":19.95}}]}
{"_id":"66cd794eca37168420771f90","CostCenter":"A50","PONumber":8328,"Reference":"ABULL-20140504","Requestor":"Alexis Bull","Special Instructions":"Counter to Counter","User":"ABULL","ShippingInstructions":{"name":"Alexis Bull","Address":{"city":"South San Francisco","country":"United States of America","state":"CA","street":"200 Sporting Green","zipCode":99236},"Phone":[{"number":"25-41-3537","type":"Office"}]},"LineItems":[{"ItemNumber":1,"Quantity":3,"Part":{"Description":"Mark Messier- Leader, Champion and Legend","UPCCode":696306000327,"UnitPrice":19.95}},{"ItemNumber":2,"Quantity":4,"Part":{"Description":"The Prophecy","UPCCode":717951001580,"UnitPrice":19.95}},{"ItemNumber":3,"Quantity":1,"Part":{"Description":"Pokemon: Johto Journeys- Team Green / Japanimat","UPCCode":13023156999,"UnitPrice":27.95}},{"ItemNumber":4,"Quantity":6,"Part":{"Description":"Airport 1975","UPCCode":18713810106,"UnitPrice":19.95}},{"ItemNumber":5,"Quantity":4,"Part":{"Description":"What Dreams May Come","UPCCode":44005827521,"UnitPrice":19.95}}]}
{"_id":"66cd794eca37168420772683","CostCenter":"A50","PONumber":8921,"Reference":"ABULL-20141101","Requestor":"Alexis Bull","Special Instructions":"Counter to Counter","User":"ABULL","ShippingInstructions":{"name":"Alexis Bull","Address":{"city":"South San Francisco","country":"United States of America","state":"CA","street":"200 Sporting Green","zipCode":99236},"Phone":[{"number":"416-555-767","type":"Office"}]},"LineItems":[{"ItemNumber":1,"Quantity":6,"Part":{"Description":"Iron Eagle","UPCCode":43396839694,"UnitPrice":19.95}},{"ItemNumber":2,"Quantity":8,"Part":{"Description":"The Siege","UPCCode":24543010913,"UnitPrice":19.95}},{"ItemNumber":3,"Quantity":2,"Part":{"Description":"Backdraft","UPCCode":25192004124,"UnitPrice":19.95}},{"ItemNumber":4,"Quantity":6,"Part":{"Description":"Truck Turner","UPCCode":27616857910,"UnitPrice":19.95}}]}
{"_id":"66cd794eca37168420772686","CostCenter":"A50","PONumber":8922,"Reference":"ABULL-20141102","Requestor":"Alexis Bull","Special Instructions":"Hand Carry","User":"ABULL","ShippingInstructions":{"name":"Alexis Bull","Address":{"city":"South San Francisco","country":"United States of America","state":"CA","street":"200 Sporting Green","zipCode":99236},"Phone":[{"number":"78-555-8375","type":"Office"}]},"LineItems":[{"ItemNumber":1,"Quantity":1,"Part":{"Description":"The Delta Force","UPCCode":27616852892,"UnitPrice":19.95}},{"ItemNumber":2,"Quantity":1,"Part":{"Description":"Apocalypse Now Redux","UPCCode":97360962949,"UnitPrice":32.95}},{"ItemNumber":3,"Quantity":7,"Part":{"Description":"Doctor Who: The Five Doctors","UPCCode":794051159625,"UnitPrice":27.95}}]}
{"_id":"66cd794eca37168420772689","CostCenter":"A50","PONumber":8923,"Reference":"ABULL-20141107","Requestor":"Alexis Bull","Special Instructions":"Courier","User":"ABULL","ShippingInstructions":{"name":"Alexis Bull","Address":{"city":"South San Francisco","country":"United States of America","state":"CA","street":"200 Sporting Green","zipCode":99236},"Phone":[{"number":"600-555-9900","type":"Office"}]},"LineItems":[{"ItemNumber":1,"Quantity":6,"Part":{"Description":"Fela Live!- Fela Anikulapo-Kuti and the Egypt 80 Band","UPCCode":16351010193,"UnitPrice":19.95}},{"ItemNumber":2,"Quantity":3,"Part":{"Description":"Herbie Mann: Jasil Brass","UPCCode":13023034495,"UnitPrice":19.95}},{"ItemNumber":3,"Quantity":7,"Part":{"Description":"Eraser","UPCCode":85391420224,"UnitPrice":19.95}}]}
{"_id":"66cd794eca3716842077268c","CostCenter":"A50","PONumber":8924,"Reference":"ABULL-20141109","Requestor":"Alexis Bull","Special Instructions":"Courier","User":"ABULL","ShippingInstructions":{"name":"Alexis Bull","Address":{"city":"South San Francisco","country":"United States of America","state":"CA","street":"200 Sporting Green","zipCode":99236},"Phone":[{"number":"728-555-9686","type":"Office"}]},"LineItems":[{"ItemNumber":1,"Quantity":5,"Part":{"Description":"Support Your Local Gunfighter","UPCCode":27616859051,"UnitPrice":19.95}},{"ItemNumber":2,"Quantity":4,"Part":{"Description":"The Four Sided Triangle","UPCCode":13131107593,"UnitPrice":19.95}},{"ItemNumber":3,"Quantity":6,"Part":{"Description":"Devil in a Blue Dress","UPCCode":43396513495,"UnitPrice":19.95}},{"ItemNumber":4,"Quantity":7,"Part":{"Description":"Nothing But Trouble","UPCCode":85391637622,"UnitPrice":19.95}},{"ItemNumber":5,"Quantity":2,"Part":{"Description":"A View to a Kill","UPCCode":27616853967,"UnitPrice":19.95}}]}
{"_id":"66cd794eca3716842077331c","CostCenter":"A50","PONumber":9996,"Reference":"ABULL-20141025","Requestor":"Alexis Bull","Special Instructions":"Courier","User":"ABULL","ShippingInstructions":{"name":"Alexis Bull","Address":{"city":"South San Francisco","country":"United States of America","state":"CA","street":"200 Sporting Green","zipCode":99236},"Phone":[{"number":"796-555-5448","type":"Office"}]},"LineItems":[{"ItemNumber":1,"Quantity":5,"Part":{"Description":"Ancient Secrets of Bible: David / Samson","UPCCode":56775056797,"UnitPrice":19.95}},{"ItemNumber":2,"Quantity":9,"Part":{"Description":"Stomp Out Loud","UPCCode":26359148422,"UnitPrice":19.95}},{"ItemNumber":3,"Quantity":4,"Part":{"Description":"The Mosquito Coast","UPCCode":85393622121,"UnitPrice":19.95}}]}
{"_id":"66cd794eca3716842077316c","CostCenter":"A50","PONumber":9852,"Reference":"ABULL-20141001","Requestor":"Alexis Bull","Special Instructions":"Expidite","User":"ABULL","ShippingInstructions":{"name":"Alexis Bull","Address":{"city":"South San Francisco","country":"United States of America","state":"CA","street":"200 Sporting Green","zipCode":99236},"Phone":[{"number":"604-555-550","type":"Office"}]},"LineItems":[{"ItemNumber":1,"Quantity":2,"Part":{"Description":"I Spy: Blackout","UPCCode":14381983425,"UnitPrice":19.95}},{"ItemNumber":2,"Quantity":6,"Part":{"Description":"The Prophecy","UPCCode":717951001580,"UnitPrice":19.95}},{"ItemNumber":3,"Quantity":4,"Part":{"Description":"Kingpin","UPCCode":27616627520,"UnitPrice":19.95}}]}
{"_id":"66cd794eca3716842077316f","CostCenter":"A50","PONumber":9853,"Reference":"ABULL-20141001","Requestor":"Alexis Bull","Special Instructions":"Expidite","User":"ABULL","ShippingInstructions":{"name":"Alexis Bull","Address":{"city":"South San Francisco","country":"United States of America","state":"CA","street":"200 Sporting Green","zipCode":99236},"Phone":[{"number":"670-555-5384","type":"Office"}]},"LineItems":[{"ItemNumber":1,"Quantity":3,"Part":{"Description":"Switch","UPCCode":26359055027,"UnitPrice":19.95}},{"ItemNumber":2,"Quantity":2,"Part":{"Description":"Grosse Point & High Fidelity","UPCCode":786936161328,"UnitPrice":32.95}},{"ItemNumber":3,"Quantity":5,"Part":{"Description":"Mysteries & Myths Of 20th Century 3","UPCCode":56775042998,"UnitPrice":19.95}}]}
{"_id":"66cd794eca37168420773172","CostCenter":"A50","PONumber":9854,"Reference":"ABULL-20141006","Requestor":"Alexis Bull","Special Instructions":"Surface Mail","User":"ABULL","ShippingInstructions":{"name":"Alexis Bull","Address":{"city":"South San Francisco","country":"United States of America","state":"CA","street":"200 Sporting Green","zipCode":99236},"Phone":[{"number":"284-555-8087","type":"Office"}]},"LineItems":[{"ItemNumber":1,"Quantity":1,"Part":{"Description":"Jackie Chan's First Strike","UPCCode":794043466922,"UnitPrice":19.95}},{"ItemNumber":2,"Quantity":5,"Part":{"Description":"Pecker","UPCCode":794043473128,"UnitPrice":19.95}},{"ItemNumber":3,"Quantity":1,"Part":{"Description":"Plenty","UPCCode":17153111903,"UnitPrice":19.95}},{"ItemNumber":4,"Quantity":1,"Part":{"Description":"Deathtrap","UPCCode":85391125624,"UnitPrice":19.95}}]}

85 rows selected. 



SQL_ID: 8zqk5j2jzta0r
*/
-- insert the report into a CLOB variable
set feedback on
var report clob;
exec :report := dbms_sqldiag.report_sql('8zqk5j2jzta0r');
--spool the file
set trimspool on
set TRIM on
 set pagesize 0
set pagesize 0
set linesize 32767
set long 1000000
set longchunksize 1000000

spool diagsql1.html
select :report report FROM dual;
spool off

