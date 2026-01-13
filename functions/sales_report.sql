/*
	The return is numeric from SUM because the data type at DB is BIGINT
	When BIGINT it will convert to NUMERIC by default by SUM()
	postgreSQL reference: https://www.postgresql.org/docs/8.2/functions-aggregate.html
*/

CREATE OR REPLACE FUNCTION sales_report (
	p_tenant_id INT, 
	p_store_id INT,
	p_start_date_epoch BIGINT DEFAULT NULL,
	p_end_date_epoch BIGINT DEFAULT NULL
) 
RETURNS TABLE (
	sum_purchased_price NUMERIC,
	sum_subtotal NUMERIC,
	sum_total_quantity NUMERIC,
	sum_discount_amount NUMERIC,
	sum_total_amount NUMERIC,
	sum_transactions BIGINT
)
AS $$
DECLARE
	v_start_date TIMESTAMPTZ;
	v_end_date TIMESTAMPTZ;
BEGIN
	-- Convert epoch to timestamptz
	v_start_date := CASE WHEN p_start_date_epoch IS NOT NULL 
						THEN to_timestamp(p_start_date_epoch) 
						ELSE NULL END;
	v_end_date := CASE WHEN p_end_date_epoch IS NOT NULL 
						THEN to_timestamp(p_end_date_epoch) 
						ELSE NULL END;

	RETURN QUERY
	SELECT
		COALESCE(SUM(purchased_price), 0) AS sum_purchased_price,
		COALESCE(SUM(subtotal), 0) AS sum_subtotal,
		COALESCE(SUM(total_quantity), 0) AS sum_total_quantity,
		COALESCE(SUM(discount_amount), 0) AS sum_discount_amount,
		COALESCE(SUM(total_amount), 0) AS sum_total_amount,
		COUNT(id) AS sum_transactions
	FROM order_item
	WHERE tenant_id = p_tenant_id
		AND (p_store_id = 0 OR store_id = p_store_id)
		AND (
		-- Both dates: range filter (gte start, lt end)
		(v_start_date IS NOT NULL AND v_end_date IS NOT NULL AND created_at >= v_start_date AND created_at < v_end_date)
		-- Only start date: from date onwards (gte)
		OR (v_start_date IS NOT NULL AND v_end_date IS NULL AND created_at >= v_start_date)
		-- Only end date: up to date (lte)
		OR (v_start_date IS NULL AND v_end_date IS NOT NULL AND created_at <= v_end_date)
		-- No dates: no filter
		OR (v_start_date IS NULL AND v_end_date IS NULL)
	);
END;
$$ LANGUAGE plpgsql;