ALTER TABLE store
ADD CONSTRAINT unique_store_name UNIQUE (name, tenant_id);