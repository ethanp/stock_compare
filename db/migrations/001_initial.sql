-- stock_compare schema for PowerSync (TEXT ids = client UUIDs)
-- Product soft-delete is_deleted is kept; PowerSync owns upload/download.

CREATE TABLE IF NOT EXISTS comparison_views (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    tickers TEXT NOT NULL,
    range_preset TEXT NOT NULL DEFAULT 'oneYear',
    start_date TEXT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    is_deleted INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_comparison_views_sort_order
    ON comparison_views(sort_order);
