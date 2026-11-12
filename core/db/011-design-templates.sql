ALTER TABLE records DROP CONSTRAINT IF EXISTS records_kind_check;
ALTER TABLE records ADD CONSTRAINT records_kind_check CHECK(kind IN ('BrandKit','Strategy','Campaign','Idea','Asset','Approval','Post','Ad','Metric','Report','Learning','Task','DesignTemplate'));
