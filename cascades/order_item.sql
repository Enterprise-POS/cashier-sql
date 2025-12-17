-- Deleting order_item row will also delete all the purchased_item_list
ALTER TABLE purchased_item_list
ADD CONSTRAINT purchased_item_list_order_item_id_fkey
FOREIGN KEY (order_item_id) 
REFERENCES order_item(id) 
ON DELETE CASCADE;