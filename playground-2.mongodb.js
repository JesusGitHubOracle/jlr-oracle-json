/* global use, db */
// MongoDB Playground
// Use Ctrl+Space inside a snippet or a string literal to trigger completions.

// The current database to use.
use('json_orders');

// Search for documents in the current collection.
db.SALES_HISTORY_DUALITY_VIEW_ALL.find({"customers.custId" : 9696});
 
    
      