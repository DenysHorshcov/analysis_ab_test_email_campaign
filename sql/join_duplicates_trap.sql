-- Питання: як JOIN з таблицею, де на одного клієнта кілька рядків, роздуває підсумки і як це виправити?
-- Очікування: "наївний" запит дає завищений spend (у стільки разів, скільки рядків на клієнта);
--             виправлений (агрегація до JOIN) збігається з еталоном 67 258,13.
-- Техніки: JOIN, DISTINCT, агрегація до JOIN, CTE.
-- Примітка: у наших даних таблиць з кількома рядками на клієнта немає (customer_id унікальний скрізь),
--   тому "лог листів" email_log змодельовано в CTE: 2 рядки на клієнта (generate_series). Нічого не пишеться в базу.
-- Висновок: наївний JOIN дає 128 000 рядків замість 64 000, spend 134 516,26 (рівно x2) і 1 156 покупців
--   (x2) проти справжніх 67 258,13 і 578. Агрегація до JOIN повертає 64 000 / 67 258,13 / 578 = еталон.
--   DISTINCT тут теж збігається з еталоном, але лише тому, що в нього входить customer_id; без нього
--   (DISTINCT по spend, conversion) різні клієнти з однаковими значеннями злились би в один рядок.

WITH email_log AS (   -- моделюємо журнал: кожному клієнту відправлено 2 повідомлення
    SELECT c.customer_id, s.touch_no
    FROM customers c
    CROSS JOIN generate_series(1, 2) AS s(touch_no)
),
naive AS (            -- ПОМИЛКА: рядок outcomes дублюється на кожен рядок журналу
    SELECT COUNT(*) AS rows_after_join,
           SUM(o.spend) AS total_spend,
           SUM(o.conversion) AS buyers
    FROM email_log l
    JOIN outcomes o USING (customer_id)
),
distinct_hack AS (    -- працює, лише поки в DISTINCT є customer_id; дорожче за агрегацію до JOIN
    SELECT COUNT(*) AS rows_after_join, SUM(spend) AS total_spend, SUM(conversion) AS buyers
    FROM (SELECT DISTINCT o.customer_id, o.spend, o.conversion
          FROM email_log l JOIN outcomes o USING (customer_id)) d
),
fixed AS (            -- ВИПРАВЛЕНО: спочатку агрегуємо журнал до рівня клієнта, потім JOIN
    SELECT COUNT(*) AS rows_after_join,
           SUM(o.spend) AS total_spend,
           SUM(o.conversion) AS buyers
    FROM (SELECT customer_id, COUNT(*) AS messages FROM email_log GROUP BY customer_id) l
    JOIN outcomes o USING (customer_id)
),
truth AS (            -- еталон: напряму з outcomes
    SELECT COUNT(*) AS rows_after_join, SUM(spend) AS total_spend, SUM(conversion) AS buyers FROM outcomes
)
SELECT 'naive JOIN (wrong)'            AS variant, * FROM naive
UNION ALL SELECT 'DISTINCT workaround',     * FROM distinct_hack
UNION ALL SELECT 'aggregate before JOIN',   * FROM fixed
UNION ALL SELECT 'truth (outcomes only)',   * FROM truth;
