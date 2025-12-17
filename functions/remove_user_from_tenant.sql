CREATE OR REPLACE FUNCTION remove_user_from_tenant(
    p_performer INT,
    p_user_id INT,
    p_tenant_id INT
)
RETURNS TEXT AS
$$
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
    FROM tenant 
    WHERE id = p_tenant_id;

    -- Check if performer is owner
    IF requested_owner_user_id != p_performer THEN
        RETURN '[ERROR] Illegal action! Removing user only allowed by the owner';
    END IF;

    -- If the user is the owner, deactivate the tenant
    IF requested_owner_user_id = p_user_id THEN
        UPDATE tenant 
        SET is_active = FALSE 
        WHERE id = p_tenant_id;
        RETURN '[SUCCESS] Current tenant will be archived';
    ELSE
        -- Otherwise remove the user from the tenant membership
        DELETE FROM user_mtm_tenant 
        WHERE user_id = p_user_id 
        AND tenant_id = p_tenant_id;

        RETURN '[SUCCESS] Removed from tenant';
    END IF;
END;
$$
LANGUAGE plpgsql;
