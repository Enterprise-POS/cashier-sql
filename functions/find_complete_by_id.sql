-- There is a same function purpose but different name. Need to examine more for detail
-- In back end, CategoryWithItem is expect to have total_count but in this function we don't use
CREATE OR REPLACE FUNCTION find_complete_by_id(
    p_tenant_id INT,
    p_item_id INT
) 
RETURNS TABLE (
    category_id BIGINT,
    category_name TEXT,
    item_id BIGINT,
    item_name TEXT,
    stock_type TEXT,
    stocks BIGINT
)
AS $$
DECLARE
    v_count INT;
BEGIN
    -- Count how many matches
    SELECT COUNT(*) INTO v_count
    FROM warehouse
    WHERE warehouse.tenant_id = p_tenant_id 
      AND warehouse.item_id = p_item_id;

    -- Handle error cases
    IF v_count = 0 THEN
        RAISE EXCEPTION '[ERROR] Item with id % not found for tenant %', p_item_id, p_tenant_id
            USING ERRCODE = 'NO_DATA_FOUND';
    ELSIF v_count > 1 THEN
        RAISE EXCEPTION '[ERROR] Multiple items (% rows) found for id % and tenant %', v_count, p_item_id, p_tenant_id
            USING ERRCODE = 'CARDINALITY_VIOLATION';
    END IF;

    -- If exactly 1 row, return the data
    RETURN QUERY
    SELECT 
        category.id AS category_id,
        category.category_name,
        warehouse.item_id,
        warehouse.item_name,
        warehouse.stock_type::TEXT,
        warehouse.stocks
    FROM warehouse
    LEFT JOIN category_mtm_warehouse 
        ON category_mtm_warehouse.item_id = warehouse.item_id
    LEFT JOIN category 
        ON category.id = category_mtm_warehouse.category_id
    WHERE warehouse.tenant_id = p_tenant_id 
      AND warehouse.item_id = p_item_id;
END;
$$ LANGUAGE plpgsql;