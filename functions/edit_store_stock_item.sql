/*
	NAME: edit_store_stock_item

	2025/11 (nov)/10
	type StoreStock struct {
		Id        int        `json:"id,omitempty"`
		Stocks    int        `json:"stocks"`
		Price     int        `json:"price"`
		CreatedAt *time.Time `json:"created_at,omitempty"`
		ItemId    int        `json:"item_id"`
		TenantId  int        `json:"tenant_id"`
		StoreId   int        `json:"store_id"`
	}

	PARAMS:
		p_store_stock_id: INT
		p_price: INT
		p_store_id: INT
		p_tenant_id: INT
*/

CREATE OR REPLACE FUNCTION edit_store_stock_item(
    p_store_stock_id INT,
    p_price INT,
    p_store_id INT,
    p_tenant_id INT,
    p_item_id INT
)
RETURNS TEXT AS $$
DECLARE
    exists_flag BOOLEAN;
BEGIN
	-- 100.000.000
	IF p_price < 0 OR p_price > 100_000_000 THEN
		RETURN format(
			'[ERROR] Invalid value for price, please check the update request price. %s is not allowed', 
			p_price
		);
	END IF;

    -- Validate if item exists
    SELECT EXISTS (
        SELECT 1 
        FROM store_stock 
        WHERE 
			item_id = p_item_id AND 
			tenant_id = p_tenant_id AND 
			store_id = p_store_id AND 
			id = p_store_stock_id
    ) INTO exists_flag;

    IF NOT exists_flag THEN
        RETURN '[ERROR] Item does not exist at this store or invalid item ID';
    END IF;

    -- Perform update
    BEGIN
        UPDATE store_stock
        SET 
            price = p_price,
            last_update = NOW()
        WHERE 
            id = p_store_stock_id AND 
			tenant_id = p_tenant_id;

        RETURN '[SUCCESS] Store stock updated successfully';
    EXCEPTION
        WHEN foreign_key_violation THEN
            RETURN format(
                '[ERROR] No stock found for tenant_id %s and store_id %s and store_stock.id %s',
                p_tenant_id, p_store_id, p_store_stock_id
            );
        WHEN OTHERS THEN
            RETURN '[FATAL ERROR] Unexpected database error';
    END;
END;
$$ LANGUAGE plpgsql;
