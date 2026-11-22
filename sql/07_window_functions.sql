-- Питання: як витрати розподілені всередині кожної групи (концентрація) і яку частку spend групи дають
--          найбільші покупці; як групи порівнюються за вкладом у загальний spend?
-- Очікування: розподіл з довгим хвостом: верхній квартиль покупців дає значно більше половини spend групи.
-- Техніки: RANK, NTILE, PERCENT_RANK, SUM() OVER (PARTITION BY segment), SUM() OVER ().
-- Як читати вікна:
--   PARTITION BY segment  = рахувати окремо всередині кожної групи (вікно "перезапускається" на новій групі);
--   ORDER BY spend DESC   = порядок усередині групи: перший = найбільший spend (для RANK/NTILE/PERCENT_RANK);
--   без PARTITION BY (SUM() OVER ()) = вікно по всіх рядках одразу.
-- Примітка: вікна рахуємо лише по покупцях (spend > 0): серед усіх клієнтів ~99% нулів і ранги були б
--   безглуздими. RANK при однакових spend дає однаковий ранг; NTILE ділить на рівні за кількістю частини.
-- Висновок: у всіх групах верхній квартиль покупців дає 55,7-60,7% spend групи (контроль 56,2%,
--   Mens 60,7%, Womens 55,7%), нижній лише ~6,2-6,6%: сильна концентрація, довгий правий хвіст.
--   Групи у загальному spend: контроль 20,7%, Mens 45,0%, Womens 34,3% (при майже рівних розмірах груп).
--   NTILE ділить за кількістю, тому однакові spend (29,99) можуть потрапити у різні квартилі (Mens 3 і 4).

WITH buyers AS (
    SELECT a.segment, o.customer_id, o.spend
    FROM assignments a
    JOIN outcomes o USING (customer_id)
    WHERE o.spend > 0
),
ranked AS (
    SELECT
        segment,
        customer_id,
        spend,
        RANK()         OVER w                                   AS spend_rank,
        PERCENT_RANK() OVER w                                   AS pct_rank,
        NTILE(4)       OVER w                                   AS spend_quartile,   -- 1 = найбільші витрати
        spend / SUM(spend) OVER (PARTITION BY segment)          AS share_of_group_spend,
        SUM(spend) OVER (PARTITION BY segment)                  AS group_spend,
        SUM(spend) OVER ()                                      AS all_spend
    FROM buyers
    WINDOW w AS (PARTITION BY segment ORDER BY spend DESC)
)
SELECT
    segment,
    spend_quartile,
    COUNT(*)                                          AS buyers,
    MIN(spend_rank)                                   AS best_rank,
    MIN(spend)                                        AS min_spend,
    MAX(spend)                                        AS max_spend,
    ROUND(SUM(spend), 2)                              AS quartile_spend,
    ROUND(100 * SUM(share_of_group_spend), 1)         AS pct_of_group_spend,
    ROUND(100 * SUM(spend) / MAX(all_spend), 1)       AS pct_of_all_spend
FROM ranked
GROUP BY segment, spend_quartile
ORDER BY CASE segment WHEN 'No E-Mail' THEN 0 WHEN 'Mens E-Mail' THEN 1 ELSE 2 END, spend_quartile;
