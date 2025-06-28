/*
  NAME: transfer_stock_to_warehouse

	PARAMS:
		p_quantity: INT
		p_item_id: INT
		p_store_id: INT
		p_tenant_id: INT
*/

DECLARE
    exists_flag BOOLEAN; -- will be used repeatedly

    current_warehouse_stock INT;
    current_store_stock INT;

    realized_warehouse_stock INT;
    realized_store_stock INT;
BEGIN
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

    -- Validate if item exist or not
    SELECT EXISTS (
        SELECT 1 FROM store_stock WHERE item_id = p_item_id AND tenant_id = p_tenant_id AND store_id = p_store_id
    ) INTO exists_flag;
    IF NOT exists_flag THEN
        RETURN '[ERROR] Not exist item at the store or invalid item';
    END IF;

    -- Get current store stock
    SELECT stocks INTO current_store_stock
    FROM store_stock
    WHERE item_id = p_item_id AND tenant_id = p_tenant_id AND store_id = p_store_id;

    -- Subtract the quantity
    realized_store_stock := current_store_stock - p_quantity;

    IF realized_store_stock >= 0 THEN
        -- Get current warehouse stock
        SELECT stocks INTO current_warehouse_stock
        FROM warehouse
        WHERE item_id = p_item_id AND tenant_id = p_tenant_id;

        -- Add quantity to warehouse stock
        realized_warehouse_stock := current_warehouse_stock + p_quantity;

        -- Update the warehouse stock
        UPDATE warehouse
        SET stocks = realized_warehouse_stock
        WHERE item_id = p_item_id AND tenant_id = p_tenant_id;

        -- Also update the store_stock stock
        UPDATE store_stock
        SET stocks = realized_store_stock
        WHERE item_id = p_item_id AND tenant_id = p_tenant_id AND store_id = p_store_id;

        RETURN '[SUCCESS] Transfer success';
    ELSE
        RETURN '[ERROR] Not enough stock';  -- Not enough stock
    END IF;
END;