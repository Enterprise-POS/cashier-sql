/*
	warehouse -LEFT JOIN-> category_mtm_warehouse -LEFT JOIN-> category

	Example use:
		SELECT * FROM find_item_by_id(333, 1417);

	2025/09/16
		type CategoryWithItem struct {
			Id           int    `json:"id,omitempty"`
			CategoryName string `json:"category_name"`

			ItemId    int    `json:"item_id,omitempty"`
			ItemName  string `json:"item_name"`
			Stocks    int    `json:"stocks"`
			BasePrice int    `json:"base_price"`
			TotalCount int 	`json:"total_count" // Will not be use for this sql query`
		}
*/

CREATE OR REPLACE FUNCTION find_item_by_id(
    p_tenant_id INT,
    p_item_id INT
)
RETURNS TABLE (
    category_id BIGINT,
    category_name TEXT,
    item_id BIGINT,
    item_name TEXT,
    stocks BIGINT,
    base_price BIGINT
)
AS $$
DECLARE
    v_count INT;
BEGIN
    -- Count how many matches
    SELECT COUNT(*) INTO v_count
    FROM warehouse
    WHERE tenant_id = p_tenant_id 
      AND item_id = p_item_id;

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
        warehouse.stocks,
        warehouse.base_price
    FROM warehouse
    LEFT JOIN category_mtm_warehouse
        ON category_mtm_warehouse.item_id = warehouse.item_id
    LEFT JOIN category
        ON category.id = category_mtm_warehouse.category_id
    WHERE warehouse.tenant_id = p_tenant_id
      AND warehouse.item_id = p_item_id;
END;
$$ LANGUAGE plpgsql;
