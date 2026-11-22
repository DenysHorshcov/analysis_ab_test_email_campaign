-- Hillstrom A/B test schema. customer_id = row number in the source CSV (it has no id).
DROP TABLE IF EXISTS outcomes, assignments, customers CASCADE;

CREATE TABLE customers (
    customer_id     INTEGER PRIMARY KEY,
    recency         SMALLINT NOT NULL CHECK (recency BETWEEN 1 AND 12),
    history_segment TEXT     NOT NULL,
    history         NUMERIC(10,2) NOT NULL CHECK (history >= 0),
    mens            SMALLINT NOT NULL CHECK (mens IN (0,1)),
    womens          SMALLINT NOT NULL CHECK (womens IN (0,1)),
    zip_code        TEXT     NOT NULL,
    newbie          SMALLINT NOT NULL CHECK (newbie IN (0,1)),
    channel         TEXT     NOT NULL
);

CREATE TABLE assignments (
    customer_id INTEGER PRIMARY KEY REFERENCES customers(customer_id),
    segment     TEXT NOT NULL CHECK (segment IN ('Mens E-Mail','Womens E-Mail','No E-Mail'))
);

CREATE TABLE outcomes (
    customer_id INTEGER PRIMARY KEY REFERENCES customers(customer_id),
    visit       SMALLINT NOT NULL CHECK (visit IN (0,1)),
    conversion  SMALLINT NOT NULL CHECK (conversion IN (0,1)),
    spend       NUMERIC(10,2) NOT NULL CHECK (spend >= 0)
);
