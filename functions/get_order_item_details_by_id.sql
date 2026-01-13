CREATE OR REPLACE FUNCTION get_order_item_details_by_id(p_order_item_id INT, p_tenant_id INT)
RETURNS TABLE (
	id BIGINT,
	item_id BIGINT,
	purchased_price BIGINT,
	quantity BIGINT,
	discount_amount BIGINT,
	total_amount BIGINT,
	
	order_item_id BIGINT,
	order_item_purchased_price BIGINT,
	order_item_subtotal BIGINT,
	order_item_total_quantity BIGINT,
	order_item_total_amount BIGINT,
	order_item_created_at TIMESTAMPTZ
)
AS $$ 
BEGIN
	RETURN QUERY
	SELECT 
	purchased_item_list.id,
	purchased_item_list.item_id, 
	purchased_item_list.purchased_price,
	purchased_item_list.quantity,
	purchased_item_list.discount_amount,
	purchased_item_list.total_amount,
	/*
	We don't request the order_item_id because
	we already know if the data return it's guaranteed
	that the order_item_id is from parameter is correct
	-- purchased_item_list_.order_item_id 
	*/

	order_item.id AS order_item_id,
	order_item.purchased_price AS order_item_purchased_price,
	order_item.subtotal AS order_item_subtotal,
	order_item.total_quantity AS order_item_total_quantity,
	order_item.total_amount AS order_item_total_amount,
	order_item.created_at AS order_item_created_at

	FROM order_item
	INNER JOIN purchased_item_list ON purchased_item_list.order_item_id = order_item.id
	WHERE order_item.tenant_id = p_tenant_id AND order_item.id = p_order_item_id;
END;
$$ LANGUAGE plpgsql;