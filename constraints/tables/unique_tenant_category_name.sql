ALTER TABLE category
ADD CONSTRAINT unique_tenant_category_name UNIQUE (tenant_id, category_name);