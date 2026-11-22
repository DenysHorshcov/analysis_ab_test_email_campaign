-- Питання: чи придатні дані для аналізу (повнота, коректність значень, логіка)?
-- Очікування: 64 000 рядків у кожній таблиці; 0 пропусків, дублікатів і "осиротілих" клієнтів;
--             значення у допустимих межах; spend > 0 тоді й лише тоді, коли conversion = 1.
-- Техніки: UNION ALL, LEFT JOIN ... IS NULL, COUNT(*) FILTER, jsonb_each для NULL по всіх колонках.
-- Примітка: у zip_code є значення 'Surburban' (так в оригінальних даних), НЕ виправляємо.
-- Висновок: усі 33 перевірки OK. По 64 000 рядків у трьох таблицях, 0 дублікатів, 0 NULL у жодній
--   колонці, 0 клієнтів без assignments/outcomes, усі значення у допустимих межах. spend > 0 тоді
--   й лише тоді, коли conversion = 1, і кожна покупка має visit = 1. Категорії: 3 segment, 3 channel,
--   3 zip_code (з 'Surburban'), 7 history_segment. Дані чисті, нічого чистити не потрібно.

WITH checks (section, check_name, found, expected) AS (

    -- 1. Кількість рядків
    SELECT 'rows', 'customers rows',   COUNT(*), 64000 FROM customers
    UNION ALL SELECT 'rows', 'assignments rows', COUNT(*), 64000 FROM assignments
    UNION ALL SELECT 'rows', 'outcomes rows',    COUNT(*), 64000 FROM outcomes

    -- 2. Дублікати customer_id
    UNION ALL SELECT 'duplicates', 'customers: duplicate customer_id',
           COUNT(*) - COUNT(DISTINCT customer_id), 0 FROM customers

    -- 3. Клієнти без запису в assignments / outcomes (anti-join)
    UNION ALL SELECT 'orphans', 'customers without assignment', COUNT(*), 0
           FROM customers c LEFT JOIN assignments a USING (customer_id)
           WHERE a.customer_id IS NULL
    UNION ALL SELECT 'orphans', 'customers without outcome', COUNT(*), 0
           FROM customers c LEFT JOIN outcomes o USING (customer_id)
           WHERE o.customer_id IS NULL

    -- 4. NULL у кожній колонці кожної таблиці
    UNION ALL SELECT 'nulls', 'customers.' || e.key, COUNT(*) FILTER (WHERE e.value = 'null'::jsonb), 0
           FROM customers t, LATERAL jsonb_each(to_jsonb(t)) e GROUP BY e.key
    UNION ALL SELECT 'nulls', 'assignments.' || e.key, COUNT(*) FILTER (WHERE e.value = 'null'::jsonb), 0
           FROM assignments t, LATERAL jsonb_each(to_jsonb(t)) e GROUP BY e.key
    UNION ALL SELECT 'nulls', 'outcomes.' || e.key, COUNT(*) FILTER (WHERE e.value = 'null'::jsonb), 0
           FROM outcomes t, LATERAL jsonb_each(to_jsonb(t)) e GROUP BY e.key

    -- 5. Допустимі значення
    UNION ALL SELECT 'ranges', 'recency outside 1..12', COUNT(*) FILTER (WHERE recency NOT BETWEEN 1 AND 12), 0 FROM customers
    UNION ALL SELECT 'ranges', 'history < 0',           COUNT(*) FILTER (WHERE history < 0), 0 FROM customers
    UNION ALL SELECT 'ranges', 'mens not in (0,1)',     COUNT(*) FILTER (WHERE mens   NOT IN (0,1)), 0 FROM customers
    UNION ALL SELECT 'ranges', 'womens not in (0,1)',   COUNT(*) FILTER (WHERE womens NOT IN (0,1)), 0 FROM customers
    UNION ALL SELECT 'ranges', 'newbie not in (0,1)',   COUNT(*) FILTER (WHERE newbie NOT IN (0,1)), 0 FROM customers
    UNION ALL SELECT 'ranges', 'visit not in (0,1)',      COUNT(*) FILTER (WHERE visit      NOT IN (0,1)), 0 FROM outcomes
    UNION ALL SELECT 'ranges', 'conversion not in (0,1)', COUNT(*) FILTER (WHERE conversion NOT IN (0,1)), 0 FROM outcomes
    UNION ALL SELECT 'ranges', 'spend < 0',               COUNT(*) FILTER (WHERE spend < 0), 0 FROM outcomes
    UNION ALL SELECT 'ranges', 'segment not in the 3 expected',
           COUNT(*) FILTER (WHERE segment NOT IN ('Mens E-Mail','Womens E-Mail','No E-Mail')), 0 FROM assignments
    UNION ALL SELECT 'ranges', 'channel not in (Phone, Web, Multichannel)',
           COUNT(*) FILTER (WHERE channel NOT IN ('Phone','Web','Multichannel')), 0 FROM customers
    UNION ALL SELECT 'ranges', 'zip_code not in (Surburban, Rural, Urban)',
           COUNT(*) FILTER (WHERE zip_code NOT IN ('Surburban','Rural','Urban')), 0 FROM customers

    -- 6. Логічна узгодженість outcomes (перевіряємо, а не припускаємо)
    UNION ALL SELECT 'logic', 'spend > 0 but conversion = 0',
           COUNT(*) FILTER (WHERE spend > 0 AND conversion = 0), 0 FROM outcomes
    UNION ALL SELECT 'logic', 'conversion = 1 but spend = 0',
           COUNT(*) FILTER (WHERE conversion = 1 AND spend = 0), 0 FROM outcomes
    UNION ALL SELECT 'logic', 'conversion = 1 but visit = 0',
           COUNT(*) FILTER (WHERE conversion = 1 AND visit = 0), 0 FROM outcomes
)
SELECT section, check_name, found, expected,
       CASE WHEN found = expected THEN 'OK' ELSE 'FAIL' END AS status
FROM checks

UNION ALL

-- 7. Унікальні значення категорій (довідково)
SELECT 'values', 'segment', COUNT(*), NULL,
       'INFO: ' || string_agg(segment || '=' || n, ', ' ORDER BY segment)
FROM (SELECT segment, COUNT(*) AS n FROM assignments GROUP BY segment) s
UNION ALL
SELECT 'values', 'channel', SUM(n), NULL, 'INFO: ' || string_agg(channel || '=' || n, ', ' ORDER BY channel)
FROM (SELECT channel, COUNT(*) AS n FROM customers GROUP BY channel) s
UNION ALL
SELECT 'values', 'zip_code', SUM(n), NULL, 'INFO: ' || string_agg(zip_code || '=' || n, ', ' ORDER BY zip_code)
FROM (SELECT zip_code, COUNT(*) AS n FROM customers GROUP BY zip_code) s
UNION ALL
SELECT 'values', 'history_segment', SUM(n), NULL, 'INFO: ' || string_agg(history_segment || '=' || n, ' | ' ORDER BY history_segment)
FROM (SELECT history_segment, COUNT(*) AS n FROM customers GROUP BY history_segment) s
ORDER BY 1, 2;
