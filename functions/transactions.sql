CREATE OR REPLACE FUNCTION public.transactions(
  p_purchased_price integer,
  p_total_quantity integer,
  p_total_amount integer,
  p_discount_amount integer,
  p_subtotal integer,
  p_items jsonb,
  p_user_id integer,
  p_tenant_id integer,
  p_store_id integer,
  p_payment_type text DEFAULT 'CASH'
)
RETURNS TABLE(v_id integer, v_created_at timestamp with time zone, v_total_amount integer, v_purchased_price integer)
 LANGUAGE plpgsql
AS $function$
DECLARE
	exists_flag BOOLEAN;
	v_order_item_id INT;
	v_order_item_created_at TIMESTAMPTZ;
	v_item JSONB;
	v_db_price INT;
	v_db_base_price INT;
	v_provided_price INT;
	v_provided_base_price INT;
	v_item_id INT;
	v_quantity INT;
	v_current_stock INT;
	v_stock_type VARCHAR(50);
	v_db_item_name TEXT;
BEGIN
	IF NOT EXISTS (SELECT 1 FROM "user" WHERE id = p_user_id) THEN
		RAISE EXCEPTION 'Fatal error: user id % does not exist', p_user_id;
    END IF;

	IF NOT EXISTS (
		SELECT 1 FROM store_stock 
		WHERE tenant_id = p_tenant_id AND store_id = p_store_id
		LIMIT 1
	) THEN
        RAISE EXCEPTION 'Fatal error: no stock found for tenant_id % and store_id %', p_tenant_id, p_store_id;
    END IF;

	IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
		RAISE EXCEPTION 'Fatal error: items array is empty';
	END IF;

	-- SECURITY CHECK: Verify all prices match database prices
	FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
	LOOP
		v_item_id := (v_item->>'item_id')::INT;
		v_provided_price := (v_item->>'store_price_snapshot')::INT;
		v_provided_base_price := (v_item->>'base_price_snapshot')::INT;
		v_quantity := (v_item->>'quantity')::INT;

		IF v_quantity <= 0 THEN
			RAISE EXCEPTION 'Invalid quantity % for item %', v_quantity, v_item_id;
		END IF;

		SELECT "store_stock".price, "store_stock".stocks, "warehouse".stock_type, "warehouse".item_name, "warehouse".base_price
		INTO v_db_price, v_current_stock, v_stock_type, v_db_item_name, v_db_base_price
		FROM store_stock
		INNER JOIN warehouse ON "warehouse".tenant_id = "store_stock".tenant_id AND "warehouse".item_id = "store_stock".item_id
		WHERE "store_stock".item_id = v_item_id
			AND "store_stock".tenant_id = p_tenant_id
			AND "store_stock".store_id = p_store_id
		FOR UPDATE OF store_stock;

		IF v_db_price IS NULL THEN
			RAISE EXCEPTION 'Security violation: Item % not found in store % for tenant %', 
				v_item_id, p_store_id, p_tenant_id;
		END IF;

		IF v_db_price != v_provided_price THEN
			RAISE EXCEPTION 'Security violation: Price mismatch for item %. Expected %, got %', 
				v_item_id, v_db_price, v_provided_price;
		END IF;

		IF v_db_base_price != v_provided_base_price THEN
			RAISE EXCEPTION 'Security violation: Price mismatch for item %. Expected %, got %', 
				v_item_id, v_db_base_price, v_provided_base_price;
		END IF;

		IF v_stock_type = 'TRACKED' THEN 
			IF v_current_stock < v_quantity THEN
				RAISE EXCEPTION 'Insufficient stock for item % (%). Available: %, Requested: %',
					v_db_item_name, v_item_id, v_current_stock, v_quantity;
			END IF;
		END IF;
	END LOOP;

	-- Verified price only  (payment_type added here)
	INSERT INTO 
		order_item (
			purchased_price, 
			total_quantity, 
			total_amount, 
			discount_amount, 
			subtotal, 
			tenant_id, 
			store_id,
			payment_type
		)
	VALUES (
		p_purchased_price,
		p_total_quantity,
		p_total_amount,
		p_discount_amount,
		p_subtotal,
		p_tenant_id,
		p_store_id,
		p_payment_type::payment_type
	) RETURNING order_item.id, order_item.created_at INTO v_order_item_id, v_order_item_created_at;

	INSERT INTO purchased_item_list (
		order_item_id,
		item_id,
		quantity,
		store_price_snapshot,
		base_price_snapshot,
		total_amount,
		item_name_snapshot,
		discount_amount
	)
	SELECT
		v_order_item_id,
		(item->>'item_id')::INT,
		(item->>'quantity')::INT,
		(item->>'store_price_snapshot')::INT,
		(item->>'base_price_snapshot')::INT,
		(item->>'total_amount')::INT,
		(item->>'item_name_snapshot')::TEXT,
		0 -- TODO: Implement discount voucher
	FROM jsonb_array_elements(p_items) AS item;

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

	RETURN QUERY SELECT v_order_item_id, v_order_item_created_at, p_total_amount, p_purchased_price;
END;
$function$;