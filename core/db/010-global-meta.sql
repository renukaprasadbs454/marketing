-- Workspace-level Meta OAuth (client_id NULL) + per-client ad account assignment.
ALTER TABLE connector_accounts ALTER COLUMN client_id DROP NOT NULL;
ALTER TABLE connector_accounts DROP CONSTRAINT IF EXISTS connector_accounts_client_id_provider_key;
CREATE UNIQUE INDEX IF NOT EXISTS connector_accounts_global_provider
  ON connector_accounts(provider) WHERE client_id IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS connector_accounts_client_provider
  ON connector_accounts(client_id, provider) WHERE client_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS client_meta_links (
  client_id uuid PRIMARY KEY REFERENCES clients(id) ON DELETE CASCADE,
  ad_account_id text NOT NULL,
  ad_account_name text,
  page_id text,
  page_name text,
  whatsapp_phone_id text,
  whatsapp_display text,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS client_meta_links_ad_account ON client_meta_links(ad_account_id);

DO $$
DECLARE
  g uuid;
  r record;
BEGIN
  SELECT id INTO g FROM connector_accounts
   WHERE provider='meta' AND client_id IS NOT NULL AND status='connected' AND token_enc IS NOT NULL
   ORDER BY updated_at DESC LIMIT 1;
  IF g IS NULL THEN
    SELECT id INTO g FROM connector_accounts
     WHERE provider='meta' AND client_id IS NOT NULL
     ORDER BY updated_at DESC LIMIT 1;
  END IF;
  IF g IS NULL THEN
    RETURN;
  END IF;
  FOR r IN SELECT * FROM connector_accounts WHERE provider='meta' AND client_id IS NOT NULL LOOP
    IF COALESCE(r.meta->>'ad_account_id','') <> '' THEN
      INSERT INTO client_meta_links(client_id, ad_account_id, ad_account_name, page_id, page_name, whatsapp_phone_id, whatsapp_display)
      VALUES (
        r.client_id,
        r.meta->>'ad_account_id',
        NULLIF(r.meta->>'ad_account_name',''),
        NULLIF(r.meta->>'page_id',''),
        NULLIF(r.meta->>'page_name',''),
        NULLIF(r.meta->>'whatsapp_phone_id',''),
        NULLIF(r.meta->>'whatsapp_display','')
      )
      ON CONFLICT (client_id) DO NOTHING;
    END IF;
  END LOOP;
  -- Drop conflicting ad-account uniques from migration duplicates (keep first)
  DELETE FROM client_meta_links a USING client_meta_links b
   WHERE a.ad_account_id=b.ad_account_id AND a.client_id>b.client_id;
  UPDATE connector_accounts SET client_id=NULL WHERE id=g;
  DELETE FROM connector_accounts WHERE provider='meta' AND client_id IS NOT NULL;
  UPDATE connector_accounts
     SET meta = COALESCE(meta,'{}'::jsonb)
       - 'ad_account_id' - 'ad_account_name' - 'page_id' - 'page_name'
       - 'whatsapp_phone_id' - 'whatsapp_display'
   WHERE id=g;
END $$;
