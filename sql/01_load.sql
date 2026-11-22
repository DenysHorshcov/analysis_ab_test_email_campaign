-- Run by src/load_data.py: it creates stg_hillstrom and COPYs the CSV into it
-- (client-side COPY), then runs this script to split it into the three tables.
INSERT INTO customers
SELECT customer_id, recency, history_segment, history, mens, womens, zip_code, newbie, channel
FROM stg_hillstrom;
INSERT INTO assignments SELECT customer_id, segment FROM stg_hillstrom;
INSERT INTO outcomes    SELECT customer_id, visit, conversion, spend FROM stg_hillstrom;
DROP TABLE stg_hillstrom;
