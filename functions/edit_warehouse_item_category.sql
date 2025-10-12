/*
	NAME: edit_warehouse_item_category

	PARAMS:
		p_category_id: INT
		p_item_id: INT
		p_tenant_id: INT
*/

DECLARE
    exists_flag BOOLEAN; -- will be used repeatedly
	is_exactly_one BOOLEAN;
BEGIN
	IF p_category_id IS NULL OR p_item_id IS NULL OR p_tenant_id IS NULL THEN
        RETURN '[ERROR] Invalid request: parameters cannot be null';
    END IF;

    IF p_category_id <= 0 OR p_item_id <= 0 THEN
        RETURN '[ERROR] Invalid request: invalid category_id or item_id';
    END IF;
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

	-- Check if the item is linked to exactly one category
    SELECT COUNT(*) = 1
    FROM category_mtm_warehouse
    WHERE item_id = p_item_id
    INTO is_exactly_one;

    IF NOT is_exactly_one THEN
        RETURN '[ERROR] Item has multiple categories either not registered by any category';
    END IF;


	-- Perform update
    BEGIN
        UPDATE category_mtm_warehouse
        SET category_id = p_category_id
        WHERE item_id = p_item_id;

        RETURN '[SUCCESS] Category updated successfully';
    EXCEPTION
        WHEN foreign_key_violation THEN
            RETURN '[ERROR] Update failed: category_id does not exist';
        WHEN OTHERS THEN
            RETURN '[ERROR] Unexpected database error';
    END;
END