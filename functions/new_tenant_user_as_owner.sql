/*
	NAME: new_tenant_user_as_owner

	PARAMS:
		p_user_id: INT
		p_tenant_name: TEXT

	USAGE:
		SELECT new_tenant_user_as_owner(1, 'test tenant group');
*/

DECLARE
    exists_flag BOOLEAN; -- will be used repeatedly

	new_tenant_id INT; -- new created tenant.id
BEGIN
	-- Validation
    IF p_tenant_name IS NULL THEN
        RETURN '[ERROR] Tenant name cannot be null';
    END IF;

    -- Check if user really exist
	SELECT EXISTS (SELECT 1 FROM "user" WHERE "user".id = p_user_id) INTO exists_flag;
    IF NOT exists_flag THEN
		RETURN '[ERROR] Fatal error, user id not existed';
    END IF;

	-- Begin inserting into tenant, after inserted immediately get the id
	INSERT INTO tenant(name, owner_user_id) VALUES (p_tenant_name, p_user_id) RETURNING id INTO new_tenant_id;

	-- Using previous tenant_id, register to user_mtm_tenant
	INSERT INTO user_mtm_tenant(user_id, tenant_id) VALUES(p_user_id, new_tenant_id);

	RETURN '[SUCCESS] New tenant created';
END;