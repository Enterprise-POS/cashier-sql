/*
	NAME: edit_warehouse_item

	PARAMS:
		p_quantity: INT (minus value (-1) is allowed here)
		p_item_name: TEXT
		p_stock_type: TEXT
		p_base_price: INT

		p_item_id: INT
		p_tenant_id: INT
*/

CREATE OR REPLACE FUNCTION edit_warehouse_item(
	p_quantity INT,
	p_item_name TEXT,
	p_stock_type TEXT,
	p_base_price INT,
	p_item_id INT,
	p_tenant_id INT
)
RETURNS TEXT
AS $$
DECLARE
    exists_flag BOOLEAN; -- will be used repeatedly

    current_warehouse_stock INT;
    realized_warehouse_stock INT;
BEGIN
	-- BE TODO:
	-- 1. IF p_quantity == 0 THEN make response immediately rather tell SQL
	-- 2. Check and validate the p_item_name

    /*
		Check if the item really exist at warehouse,
		If never even exist, this will cause serious error
    */
    SELECT EXISTS (
        SELECT 1 FROM warehouse WHERE item_id = p_item_id AND tenant_id = p_tenant_id
    ) INTO exists_flag;
    IF NOT exists_flag THEN
		RETURN '[ERROR] Fatal error, current item from store never exist at warehouse';
    END IF;

	-- Validate stock_type ENUM value
	IF p_stock_type NOT IN ('TRACKED', 'UNLIMITED') THEN
		RETURN format(
			'[ERROR] Invalid stock_type value. Must be TRACKED or UNLIMITED, got: %s',
			p_stock_type
		);
	END IF;

	-- Get current stock
	SELECT stocks INTO current_warehouse_stock
	FROM warehouse 
	WHERE item_id = p_item_id AND tenant_id = p_tenant_id;

    -- Adjust the stock: p_quantity can be positive or negative
    realized_warehouse_stock := current_warehouse_stock + p_quantity;

    IF realized_warehouse_stock >= 0 THEN
        -- Apply update
        UPDATE warehouse
        SET stocks = realized_warehouse_stock,
            item_name = p_item_name,
			stock_type = p_stock_type::stock_type,
			base_price = p_base_price
        WHERE item_id = p_item_id AND tenant_id = p_tenant_id;
    ELSE
        RETURN '[ERROR] Invalid quantities';
    END IF;

	RETURN 'SUCCESS';
END;
$$ LANGUAGE plpgsql;