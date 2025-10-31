/*
	store_stock -INNER JOIN-> warehouse

	Example use:
		param 1: tenant id
		param 2: store id
		param 3: limit
		param 4: offset
		param 5: name query for like query
		SELECT * FROM get_store_stocks(1, 2, 10, 0, "some name");

	2025/10/30
		type StoreStockV2 struct {
			Id         int        `json:"id,omitempty"`
			ItemName   string     `json:"item_name"`
			Stocks     int        `json:"stocks"` // StoreStock Stock
			Price      int        `json:"price"`
			CreatedAt  *time.Time `json:"created_at,omitempty"` // Warehouse Item created_at
			ItemId     int        `json:"item_id"`
			TotalCount int        `json:"total_count"`
		}
*/

CREATE OR REPLACE FUNCTION get_store_stocks(p_tenant_id INT, p_store_id INT, p_limit INT, p_offset INT, p_name_query TEXT)
RETURNS TABLE (
	id BIGINT, -- int8
	item_id BIGINT, -- int8
	item_name TEXT,
	price BIGINT, -- int8
	stocks BIGINT, -- int8
	created_at TIMESTAMPTZ, -- store_stock item created_at

	total_count BIGINT -- int8
)
AS $$ 
DECLARE
    exists_flag BOOLEAN; -- will be used repeatedly
BEGIN
	SELECT EXISTS (
        SELECT 1 FROM store_stock WHERE tenant_id = p_tenant_id AND store_id = p_store_id
    ) INTO exists_flag;

    IF NOT exists_flag THEN
        RAISE EXCEPTION 'Fatal error: no stock found for tenant_id % and store_id %', p_tenant_id, p_store_id;
    END IF;

	RETURN QUERY
	SELECT 
    store_stock.id,
    warehouse.item_id,
    warehouse.item_name,
    store_stock.price,
    store_stock.stocks,
    store_stock.created_at,
    COUNT(*) OVER() AS total_count
	FROM store_stock 
	INNER JOIN warehouse 
		ON warehouse.item_id=store_stock.item_id
	WHERE 
		store_stock.tenant_id = p_tenant_id 
		AND store_stock.store_id=p_store_id
		AND (
			p_name_query IS NULL
			OR p_name_query = ''
			OR warehouse.item_name ILIKE '%' || p_name_query || '%'
		)
	LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;