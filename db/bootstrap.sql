-- stock_compare role bootstrap
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'stock_compare') THEN
    CREATE ROLE stock_compare LOGIN;
  END IF;
END
$$;

ALTER ROLE stock_compare WITH REPLICATION;
