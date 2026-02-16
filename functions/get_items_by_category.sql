/*
	warehouse -INNER JOIN-> category_mtm_warehouse -INNER JOIN-> category

	Example use:
		SELECT * FROM get_items_by_category(1, 2, 10, 0);

	2025/10/30
		type CategoryWithItem struct {
			CategoryId int `json:"category_id"`

			CategoryName string `json:"category_name"`

			ItemId    int    `json:"item_id"`
			ItemName  string `json:"item_name"`
			Stocks    int    `json:"stocks"`
			BasePrice int    `json:"base_price"`

			TotalCount int `json:"total_count"`
		}
*/

CREATE OR REPLACE FUNCTION get_items_by_category (p_tenant_id INT, p_category_id INT, p_limit INT, p_offset INT)
RETURNS TABLE (
	category_id BIGINT, -- int8
	category_name TEXT,

	item_id BIGINT, -- int8
	item_name TEXT,
	stocks BIGINT,
	base_price BIGINT,

	total_count BIGINT -- int8
)
AS $$
BEGIN
	RETURN QUERY
	SELECT
		category.id AS category_id,
		category.category_name,
		warehouse.item_id,
		warehouse.item_name,
		warehouse.stocks,
		warehouse.base_price,
        COUNT(*) OVER() AS total_count
	FROM warehouse
	INNER JOIN category_mtm_warehouse
		ON category_mtm_warehouse.item_id = warehouse.item_id
	INNER JOIN category
		ON category.id = category_mtm_warehouse.category_id
	WHERE warehouse.tenant_id = p_tenant_id AND category.id = p_category_id
	LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;