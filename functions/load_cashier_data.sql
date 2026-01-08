/*
	Example use:
		param 1: tenant id
		param 2: store id
		SELECT * FROM load_cashier_data(333, 141);

	2026/1/3
		type CashierData struct {
			CategoryId   int    `json:"category_id"`
			CategoryName string `json:"category_name"`

			ItemId    int       `json:"item_id"`
			ItemName  string    `json:"item_name"`
			Stocks    int       `json:"stocks"`
			StockType StockType `json:"stock_type"`
			IsActive  bool      `json:"is_active"`

			StoreStockId     int `json:"store_stock_id"`
			StoreStockStocks int `json:"store_stock_stocks"`
			StoreStockPrice  int `json:"store_stock_price"`
		}
*/

CREATE OR REPLACE FUNCTION load_cashier_data(p_tenant_id INT, p_store_id INT) 
RETURNS TABLE (
	category_id BIGINT, -- int8
	category_name TEXT,
	
	item_id BIGINT, -- int8
	item_name TEXT,
	stocks BIGINT,
	stock_type TEXT,
	is_active BOOLEAN,

	store_stock_id BIGINT,
	store_stock_stocks BIGINT,
	store_stock_price BIGINT
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
		warehouse.stock_type::TEXT,
		warehouse.is_active,

		store_stock.id AS store_stock_id,
		store_stock.stocks AS store_stock_stocks,
		store_stock.price AS store_stock_price
	FROM warehouse
	INNER JOIN store_stock 
		ON store_stock.item_id = warehouse.item_id 
		AND store_stock.store_id = p_store_id
	LEFT JOIN category_mtm_warehouse 
		ON category_mtm_warehouse.item_id = warehouse.item_id
	LEFT JOIN category 
		ON category.id = category_mtm_warehouse.category_id
	WHERE warehouse.tenant_id = p_tenant_id;
END;
$$ LANGUAGE plpgsql;