/*
	NAME: transfer_stock_to_store_stock

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
    -- Validate if item exist or not and user send to valid store
    SELECT EXISTS (
        SELECT 1 FROM warehouse 
			JOIN store
			ON store.tenant_id = warehouse.tenant_id
		WHERE 
            warehouse.item_id = p_item_id 
            AND warehouse.tenant_id = p_tenant_id 
            AND store.id = p_store_id
    ) INTO exists_flag;

    IF NOT exists_flag THEN
        RETURN '[ERROR] Not exist item at the warehouse or invalid item';
    END IF;

    /*
		Check if the stock exists, 
		necessary otherwise it will update non existing row which is success but unexpected condition
    */
    SELECT EXISTS (
        SELECT 1 FROM store_stock WHERE item_id = p_item_id AND tenant_id = p_tenant_id AND store_id = p_store_id
    ) INTO exists_flag;

    IF exists_flag THEN
        -- Get current warehouse stock
        SELECT stocks INTO current_warehouse_stock
        FROM warehouse
        WHERE item_id = p_item_id AND tenant_id = p_tenant_id;

        -- Subtract the quantity
        realized_warehouse_stock := current_warehouse_stock - p_quantity;

        IF realized_warehouse_stock >= 0 THEN
            -- Get current store stock
            SELECT stocks INTO current_store_stock
            FROM store_stock
            WHERE item_id = p_item_id AND tenant_id = p_tenant_id AND store_id = p_store_id;

            -- Add quantity to store stock
            realized_store_stock := current_store_stock + p_quantity;

            -- Update the store stock
            UPDATE store_stock
            SET stocks = realized_store_stock
            WHERE item_id = p_item_id AND tenant_id = p_tenant_id AND store_id = p_store_id;

            -- Also update the warehouse stock
            UPDATE warehouse
            SET stocks = realized_warehouse_stock
            WHERE item_id = p_item_id AND tenant_id = p_tenant_id;

            RETURN '[SUCCESS] Transfer success';
        ELSE
            RETURN '[ERROR] Not enough stock';  -- Not enough stock
        END IF;
    ELSE
        -- Do not insert if the quantity is minus (ex: -1)
        -- backend should do this verification
		-- Insert new store stock only if quantity is valid
        IF p_quantity < 0 THEN
            RETURN '[ERROR] Invalid quantity for new stock';
        END IF;

		-- Insert to store
        INSERT INTO store_stock(item_id, stocks, store_id, tenant_id) VALUES (p_item_id, p_quantity, p_store_id, p_tenant_id);

		-- Get current warehouse stock
        SELECT stocks INTO current_warehouse_stock
        FROM warehouse
        WHERE item_id = p_item_id AND tenant_id = p_tenant_id;
		
		-- Subtract warehouse stocks
        realized_warehouse_stock := current_warehouse_stock - p_quantity;

		-- Also update the warehouse stock
		UPDATE warehouse
		SET stocks = realized_warehouse_stock
		WHERE item_id = p_item_id AND tenant_id = p_tenant_id;

        RETURN '[SUCCESS] New item transfer success';
    END IF;
END;