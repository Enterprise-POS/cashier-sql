/*
	user <-INNER JOIN- user_mtm_tenant -INNER JOIN-> tenant

	Example use:
		SELECT * FROM get_tenant_base_on_user_id(1);

	2025/08/15
		type Tenant struct {
			Id          int        `json:"id,omitempty"`
			Name        string     `json:"name"`
			OwnerUserId int        `json:"owner_user_id"`
			CreatedAt   *time.Time `json:"created_at,omitempty"`
		}
*/

CREATE OR REPLACE FUNCTION get_tenant_base_on_user_id (p_user_id INT) 
RETURNS TABLE (
	id BIGINT, -- int8 / tenant_id
	name TEXT,
	
	owner_user_id BIGINT, -- int8 / tenant.owner_user_id
	created_at TIMESTAMP WITH TIME ZONE
)
AS $$ 
BEGIN
	RETURN QUERY
	SELECT
		tenant.id AS id, 
		tenant.name AS name, 
		
		tenant.owner_user_id,
		tenant.created_at 
	FROM user_mtm_tenant 
		INNER JOIN "user" ON "user".id = user_mtm_tenant.user_id 
		INNER JOIN tenant ON tenant.id = user_mtm_tenant.tenant_id 
	WHERE "user".id = p_user_id;
END;
$$ LANGUAGE plpgsql;