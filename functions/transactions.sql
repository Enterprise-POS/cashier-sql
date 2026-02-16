/*
	Example usage:
		SELECT transactions(
			20000,
			2,
			20000,
			0,
			20000,
			'[
				{
					"id": 1,
					"item_id": 1,
					"quantity": 2,
					"store_price_snapshot": 10000,
					"total_amount": 20000,
					"discount_amount": 0,
					"item_name_snapshot": "Some Item Name at that transaction time"
				}
			]'::JSONB,

			1,
			1,
			1
		);

		order_item_id will be generate by the syntax,
		you don't need ::JSONB if using supabase Rpc for Go
*/

CREATE OR REPLACE FUNCTION transactions (
	p_purchased_price INT, 
    p_total_quantity INT, 
    p_total_amount INT, 
    p_discount_amount INT, 
    p_subtotal INT,

	p_items JSONB,
	
	-- Validation
	p_user_id INT,
	p_tenant_id INT, 
    p_store_id INT
) 
RETURNS INT
AS $$
DECLARE
	exists_flag BOOLEAN;
	v_order_item_id INT;
	v_item JSONB;
	v_db_price INT;
	v_provided_price INT;
	v_item_id INT;
	v_quantity INT;
	v_current_stock INT;
	v_stock_type VARCHAR(50);
	v_db_item_name TEXT;
BEGIN
	-- Future suggestion: 
	-- 		Maybe this may affect the performance, as long as no performance issue
	-- 		then this code may remain. Suggestion is use INDEX for user id, tenant id, store id
	-- Check if user really exist
	-- Validate user exists (single query)
	IF NOT EXISTS (SELECT 1 FROM "user" WHERE id = p_user_id) THEN
		RAISE EXCEPTION 'Fatal error: user id % does not exist', p_user_id;
    END IF;

	-- Check
	-- Validate store exists (single query)
	IF NOT EXISTS (
		SELECT 1 FROM store_stock 
		WHERE tenant_id = p_tenant_id AND store_id = p_store_id
		LIMIT 1
	) THEN
        RAISE EXCEPTION 'Fatal error: no stock found for tenant_id % and store_id %', p_tenant_id, p_store_id;
    END IF;

	-- Before the bulk insert, add:
	IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
		RAISE EXCEPTION 'Fatal error: items array is empty';
	END IF;

	-- SECURITY CHECK: Verify all prices match database prices
	FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
	LOOP
		v_item_id := (v_item->>'item_id')::INT;
		v_provided_price := (v_item->>'store_price_snapshot')::INT;
		v_quantity := (v_item->>'quantity')::INT;

		IF v_quantity <= 0 THEN
			RAISE EXCEPTION 'Invalid quantity % for item %', v_quantity, v_item_id;
		END IF;
		
		-- Fetch actual price and stock_type from database
		SELECT "store_stock".price, "store_stock".stocks, "warehouse".stock_type, "warehouse".item_name
		INTO v_db_price, v_current_stock, v_stock_type, v_db_item_name
		FROM store_stock
		INNER JOIN warehouse ON "warehouse".tenant_id = "store_stock".tenant_id AND "warehouse".item_id = "store_stock".item_id
		WHERE "store_stock".item_id = v_item_id
			AND "store_stock".tenant_id = p_tenant_id
			AND "store_stock".store_id = p_store_id
		FOR UPDATE OF store_stock;

		-- Check if item exists
		IF v_db_price IS NULL THEN
			RAISE EXCEPTION 'Security violation: Item % not found in store % for tenant %', 
				v_item_id, p_store_id, p_tenant_id;
		END IF;
		
		-- Check if price matches
		IF v_db_price != v_provided_price THEN
			RAISE EXCEPTION 'Security violation: Price mismatch for item %. Expected %, got %', 
				v_item_id, v_db_price, v_provided_price;
		END IF;

		-- Check stock availability
		IF v_stock_type = 'TRACKED' THEN 
			IF v_current_stock < v_quantity THEN
				RAISE EXCEPTION 'Insufficient stock for item % (%). Available: %, Requested: %',
					v_db_item_name, v_item_id, v_current_stock, v_quantity;
			END IF;
		END IF;
	END LOOP;

	-- Verified price only
	INSERT INTO 
		order_item (
			purchased_price, 
			total_quantity, 
			total_amount, 
			discount_amount, 
			subtotal, 
			tenant_id, 
			store_id
		)
	VALUES (
		p_purchased_price,
		p_total_quantity,
		p_total_amount,
		p_discount_amount,
		p_subtotal,
		p_tenant_id,
		p_store_id
	) RETURNING id INTO v_order_item_id;

	-- Bulk insert items
	INSERT INTO purchased_item_list (
		order_item_id,
		item_id,
		quantity,
		store_price_snapshot,
		total_amount,
		item_name_snapshot,
		discount_amount
	)
	SELECT 
		v_order_item_id,
		(item->>'item_id')::INT,
		(item->>'quantity')::INT,
		(item->>'store_price_snapshot')::INT,
		(item->>'total_amount')::INT,
		(item->>'item_name_snapshot')::TEXT,
		0 -- (item->>'discount_amount')::INT TODO: Implement discount voucher
	FROM jsonb_array_elements(p_items) AS item;

	-- Deduct stock for all items
	UPDATE store_stock
	SET 
		stocks = store_stock.stocks - items.qty
	FROM (
		SELECT 
			(item->>'item_id')::INT as item_id,
			(item->>'quantity')::INT as qty
		FROM jsonb_array_elements(p_items) AS item
	) items
	INNER JOIN warehouse ON warehouse.item_id = items.item_id AND warehouse.tenant_id = p_tenant_id
	WHERE "store_stock".item_id = items.item_id
		AND "store_stock".tenant_id = p_tenant_id
		AND "store_stock".store_id = p_store_id
		AND warehouse.stock_type = 'TRACKED';

	RETURN v_order_item_id;
END;
$$ LANGUAGE plpgsql;