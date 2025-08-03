/*
	NAME: remove_user_from_tenant

	PARAMS:
		p_user_id: INT
		p_tenant_id: INT

	USAGE:
		SELECT remove_user_from_tenant(1, 123);

	EXAMPLE RETURN:
		SUCCESS (OWNER)
		-- SELECT remove_user_from_tenant(1, 1);
		-- [SUCCESS] Current tenant will be archived

		USER ID NOT FOUND
		-- SELECT remove_user_from_tenant(0, 1);
		-- [ERROR] Fatal error, user id not existed

		TENANT ID NOT FOUND
		-- SELECT remove_user_from_tenant(1, 0);
		-- [ERROR] Fatal error, tenant id not existed

		SUCCESS (NOT OWNER)
		-- SELECT remove_user_from_tenant(83, 56);
		-- [SUCCESS] Removed from tenant
*/

DECLARE
    exists_flag BOOLEAN;
    requested_owner_user_id INT;
BEGIN
    -- Check if user exists
    SELECT EXISTS (SELECT 1 FROM "user" WHERE id = p_user_id) INTO exists_flag;
    IF NOT exists_flag THEN
        RETURN '[ERROR] Fatal error, user id not existed';
    END IF;

    -- Check if tenant exists
    SELECT EXISTS (SELECT 1 FROM tenant WHERE id = p_tenant_id) INTO exists_flag;
    IF NOT exists_flag THEN
        RETURN '[ERROR] Fatal error, tenant id not existed';
    END IF;

    -- Get owner_user_id of the tenant
    SELECT owner_user_id 
    INTO requested_owner_user_id
    FROM tenant WHERE id = p_tenant_id;

    -- Check if the user is the owner
    IF requested_owner_user_id = p_user_id THEN
        UPDATE tenant SET is_active = FALSE WHERE id = p_tenant_id;
        RETURN '[SUCCESS] Current tenant will be archived';
    ELSE
        DELETE FROM user_mtm_tenant WHERE user_id = p_user_id AND tenant_id = p_tenant_id;

		RETURN '[SUCCESS] Removed from tenant';
    END IF;
END;
