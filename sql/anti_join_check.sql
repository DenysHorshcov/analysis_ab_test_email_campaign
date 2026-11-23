-- Питання: чи є клієнти без призначення або без результатів (і навпаки)?
-- Очікування: 0 у всіх напрямках (кожен customer_id є в усіх трьох таблицях рівно один раз).
-- Техніки: LEFT JOIN + IS NULL (anti-join), UNION ALL.
-- Примітка: "приклади" порожні, якщо знайдено 0. Для цього запиту порожній результат прикладів = добре.
-- Висновок: усі 6 напрямків: 0 знайдено, статус OK, масив прикладів порожній ({}). Кожен customer_id є
--   в customers, assignments і outcomes; осиротілих записів немає.

WITH orphans AS (
    SELECT 'customers without assignment' AS issue, c.customer_id
    FROM customers c LEFT JOIN assignments a USING (customer_id) WHERE a.customer_id IS NULL
    UNION ALL
    SELECT 'customers without outcome', c.customer_id
    FROM customers c LEFT JOIN outcomes o USING (customer_id) WHERE o.customer_id IS NULL
    UNION ALL
    SELECT 'assignments without customer', a.customer_id
    FROM assignments a LEFT JOIN customers c USING (customer_id) WHERE c.customer_id IS NULL
    UNION ALL
    SELECT 'outcomes without customer', o.customer_id
    FROM outcomes o LEFT JOIN customers c USING (customer_id) WHERE c.customer_id IS NULL
    UNION ALL
    SELECT 'assignments without outcome', a.customer_id
    FROM assignments a LEFT JOIN outcomes o USING (customer_id) WHERE o.customer_id IS NULL
    UNION ALL
    SELECT 'outcomes without assignment', o.customer_id
    FROM outcomes o LEFT JOIN assignments a USING (customer_id) WHERE a.customer_id IS NULL
),
issues (issue) AS (
    VALUES ('customers without assignment'), ('customers without outcome'),
           ('assignments without customer'), ('outcomes without customer'),
           ('assignments without outcome'),  ('outcomes without assignment')
)
SELECT
    i.issue,
    COUNT(o.customer_id)                                             AS found,
    0                                                                AS expected,
    CASE WHEN COUNT(o.customer_id) = 0 THEN 'OK' ELSE 'FAIL' END     AS status,
    COALESCE((ARRAY_AGG(o.customer_id ORDER BY o.customer_id) FILTER (WHERE o.customer_id IS NOT NULL))[1:5], '{}') AS example_ids
FROM issues i
LEFT JOIN orphans o USING (issue)
GROUP BY i.issue
ORDER BY i.issue;
