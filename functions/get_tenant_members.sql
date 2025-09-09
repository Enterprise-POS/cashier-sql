/*
	user <-INNER JOIN- user_mtm_tenant

	Example use:
		SELECT * FROM get_tenant_members(1);

	2025/08/08
		type User struct {
			Id        int        `json:"id,omitempty"`
			UserUuid  string     `json:"user_uuid,omitempty"`
			Name      string     `json:"name"`
			Email     string     `json:"email"`
			CreatedAt *time.Time `json:"created_at,omitempty"`
		}
*/

CREATE OR REPLACE FUNCTION get_tenant_members (p_tenant_id INT) 
RETURNS TABLE (
	id BIGINT,
	user_uuid TEXT,  -- Changed from UUID to TEXT
	name TEXT,
	email TEXT,
	created_at TIMESTAMP WITH TIME ZONE	
)
AS $$ 
BEGIN
	RETURN QUERY
	SELECT "user".id, "user".user_uuid, "user".name, "user".email, "user".created_at
		FROM user_mtm_tenant
		INNER JOIN "user" ON "user".id = user_mtm_tenant.user_id
		WHERE user_mtm_tenant.tenant_id = p_tenant_id;
END;
$$ LANGUAGE plpgsql;