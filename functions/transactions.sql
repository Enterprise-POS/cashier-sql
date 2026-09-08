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
	p_payment_type text DEFAULT 'CASH',
	p_transaction_id text DEFAULT NULL,
	p_payment_url text DEFAULT NULL,
	p_payment_token text DEFAULT NULL
)
RETURNS TABLE(
	v_id integer,
	v_created_at timestamp with time zone,
	v_total_amount integer,
	v_purchased_price integer,
	v_payment_status payment_status,
	v_payment_url text,
	v_payment_token text
)
 LANGUAGE plpgsql
AS $function$
DECLARE
	v_order_item_id          INT;
	v_order_item_created_at  TIMESTAMPTZ;
	v_payment_status         payment_status DEFAULT 'SUCCESS';
	v_error                  RECORD;  -- holds the first invalid item, if any
BEGIN
	-- ---------------------------------------------------------------------
	-- 1. Cheap guard clauses first (fail fast, before touching stock rows)
	-- ---------------------------------------------------------------------
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
	
	IF p_payment_type = 'QRIS' THEN
		IF p_transaction_id IS NULL OR p_transaction_id = '' THEN
		RAISE EXCEPTION 'Invalid transaction id parameter for payment type QRIS';
		END IF;

		v_payment_status := 'PENDING';
	END IF;

	-- ---------------------------------------------------------------------
	-- 2. Validate every item in ONE set-based query (replaces the old loop)
	--
	--    parsed_items: unpack the client's JSON payload, keeping original
	--                  array order via WITH ORDINALITY.
	--    locked:       the authoritative, row-locked DB state for those items.
	--    checked:      per-item comparison of "client claims" vs. "DB truth",
	--                  producing an error_type label (or NULL if the item is
	--                  fine) using the SAME precedence as the original loop:
	--                  quantity -> existence -> price -> base price -> stock.
	-- ---------------------------------------------------------------------
	-- step 1 parsed_items: unpacking the JSON array
	-- create temporarily table with name parsed_item from keyword AS
	WITH parsed_items AS (
		SELECT
		ord                                   AS item_seq,
		(item->>'item_id')::INT               AS item_id,
		(item->>'quantity')::INT              AS quantity,
		(item->>'store_price_snapshot')::INT  AS store_price_snapshot,
		(item->>'base_price_snapshot')::INT   AS base_price_snapshot
		FROM jsonb_array_elements(p_items) 
		-- WITH ORDINALITY 
		-- a modifier you can attach to any set-returning function. 
		-- It adds an extra column containing each row's position in the original array (1, 2, 3, ...)
		WITH ORDINALITY 
		-- AS t(item, ord) — names the two output columns from that
		--  function call: item (the JSON object)
		--  and ord (the position number). t is just an alias for this inline "table."
		AS t(item, ord)
	),
	-- step 2
	-- AS MATERIALIZED — an instruction to Postgres: actually run this CTE
	--  as its own step and store the result, rather than "inlining"
	--  it into whatever queries it (which Postgres 12+ does by default for simple CTEs). 
	-- This matters here because of FOR UPDATE below — you want the locking 
	-- to happen predictably, as one discrete operation, not folded into some other query plan.
	locked AS MATERIALIZED (
		SELECT ss.item_id, ss.price, ss.stocks, w.stock_type, w.item_name, w.base_price
		FROM store_stock ss
		INNER JOIN warehouse w
		ON w.tenant_id = ss.tenant_id AND w.item_id = ss.item_id
		WHERE ss.tenant_id = p_tenant_id
		AND ss.store_id = p_store_id
		AND ss.item_id IN (SELECT item_id FROM parsed_items)
		ORDER BY ss.item_id            -- canonical lock order avoids deadlocks
		FOR UPDATE OF ss
	),
	-- checked temporarily table will contain column as checked(item_seq, item_id, ..., error_type)
	checked AS (
		SELECT
		p.item_seq,
		p.item_id,
		p.quantity,
		p.store_price_snapshot,
		p.base_price_snapshot,
		l.price       AS db_price,
		l.base_price  AS db_base_price,
		l.stocks      AS db_stock,
		l.stock_type  AS db_stock_type,
		l.item_name   AS db_item_name,

		-- Will return value with name column error_type
		CASE
			WHEN p.quantity <= 0                                   THEN 'invalid_quantity'
			WHEN l.item_id IS NULL                                 THEN 'not_found'
			WHEN l.price != p.store_price_snapshot                 THEN 'price_mismatch'
			WHEN l.base_price != p.base_price_snapshot             THEN 'base_price_mismatch'
			WHEN l.stock_type = 'TRACKED' AND l.stocks < p.quantity THEN 'insufficient_stock'
			ELSE NULL
		END AS error_type
		FROM parsed_items p
		LEFT JOIN locked l ON l.item_id = p.item_id
	)
	SELECT *
	INTO v_error
	FROM checked
	WHERE error_type IS NOT NULL
	ORDER BY item_seq              -- report the first invalid item, in payload order
	LIMIT 1;
	
	-- The moment this SELECT ... INTO finishes and detected error_type, PL/pgSQL sets FOUND -> 'true'
	-- If no error then this FOUND value will 'false'
	IF FOUND THEN
		CASE v_error.error_type
		WHEN 'invalid_quantity' THEN
			RAISE EXCEPTION 'Invalid quantity % for item %', v_error.quantity, v_error.item_id;
		WHEN 'not_found' THEN
			RAISE EXCEPTION 'Security violation: Item % not found in store % for tenant %',
			v_error.item_id, p_store_id, p_tenant_id;
		WHEN 'price_mismatch' THEN
			RAISE EXCEPTION 'Security violation: Price mismatch for item %. Expected %, got %',
			v_error.item_id, v_error.db_price, v_error.store_price_snapshot;
		WHEN 'base_price_mismatch' THEN
			RAISE EXCEPTION 'Security violation: Price mismatch for item %. Expected %, got %',
			v_error.item_id, v_error.db_base_price, v_error.base_price_snapshot;
		WHEN 'insufficient_stock' THEN
			RAISE EXCEPTION 'Insufficient stock for item % (%). Available: %, Requested: %',
			v_error.db_item_name, v_error.item_id, v_error.db_stock, v_error.quantity;
		END CASE;
	END IF;

	-- ---------------------------------------------------------------------
	-- 3. All items validated (and their stock rows are still locked from the
	--    query above, within this same transaction) — safe to write the order.
	-- ---------------------------------------------------------------------
	INSERT INTO order_item (
		purchased_price, total_quantity, total_amount, discount_amount, subtotal,
		tenant_id, store_id, payment_type, payment_status, transaction_id,
		payment_url, payment_token
	)
	VALUES (
		p_purchased_price, p_total_quantity, p_total_amount, p_discount_amount, p_subtotal,
		p_tenant_id, p_store_id, p_payment_type::payment_type, v_payment_status, p_transaction_id,
		p_payment_url, p_payment_token
	)
	RETURNING order_item.id, order_item.created_at INTO v_order_item_id, v_order_item_created_at;
	
	-- Always record what was ordered, regardless of payment status
	INSERT INTO purchased_item_list (
		order_item_id, item_id, quantity, store_price_snapshot, base_price_snapshot,
		total_amount, item_name_snapshot, discount_amount
	)
	SELECT
		v_order_item_id,
		(item->>'item_id')::INT,
		(item->>'quantity')::INT,
		(item->>'store_price_snapshot')::INT,
		(item->>'base_price_snapshot')::INT,
		(item->>'total_amount')::INT,
		(item->>'item_name_snapshot')::TEXT,
		0
	FROM jsonb_array_elements(p_items) AS item;
	
	-- Only decrement stock once payment is confirmed
	IF v_payment_status = 'PENDING' THEN
		-- PENDING: don't decrease stock yet (see note re: the overselling race
		-- condition for pending QRIS orders)
		NULL;
	ELSE
		UPDATE store_stock
		SET stocks = store_stock.stocks - items.qty
		FROM (
		SELECT
			(item->>'item_id')::INT  AS item_id,
			(item->>'quantity')::INT AS qty
		FROM jsonb_array_elements(p_items) AS item
		) items
		INNER JOIN warehouse
		ON warehouse.item_id = items.item_id
		AND warehouse.tenant_id = p_tenant_id
		WHERE store_stock.item_id = items.item_id
		AND store_stock.tenant_id = p_tenant_id
		AND store_stock.store_id = p_store_id
		AND warehouse.stock_type = 'TRACKED';
	END IF;
	
	RETURN QUERY SELECT v_order_item_id, v_order_item_created_at, p_total_amount, p_purchased_price, v_payment_status, p_payment_url, p_payment_token;
END;
$function$;