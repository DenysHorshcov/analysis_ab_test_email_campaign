-- Питання: скільки в середньому витрачає клієнт у кожній групі (з нулями і лише серед покупців)?
-- Очікування: spend сильно зміщений: майже всі нулі, тому середнє серед покупців значно більше
--             за середнє на клієнта; у покупців середнє більше за медіану (правий хвіст).
-- Техніки: AVG, PERCENTILE_CONT, COUNT FILTER.
-- Примітка: викиди не видаляємо (великі покупки і є сигнал). Тести (Welch, Mann-Whitney, bootstrap) у Python.
-- Висновок: нулі: 99,43% (контроль), 98,75% (Mens), 99,12% (Womens). Середній spend на клієнта:
--   0,6528 (контроль), 1,4226 (Mens), 1,0772 (Womens). Серед покупців середнє майже однакове
--   (114,00 / 113,53 / 121,89), тож приріст витрат іде від більшої кількості покупців, а не від
--   більшого чека. Середнє суттєво більше за медіану (напр. Mens 113,53 проти 66,98), максимум
--   499 в усіх групах: розподіл з довгим правим хвостом, тому окрім t-тесту потрібні Mann-Whitney
--   і bootstrap. Сума витрат 13 908,33 + 30 311,69 + 23 038,11 = 67 258,13.

SELECT
    a.segment,
    COUNT(*)                                                              AS n,
    COUNT(*) FILTER (WHERE o.spend > 0)                                   AS buyers,
    ROUND(100.0 * COUNT(*) FILTER (WHERE o.spend = 0) / NULLIF(COUNT(*), 0), 2) AS zero_spend_pct,
    ROUND(SUM(o.spend), 2)                                                AS total_spend,
    ROUND(AVG(o.spend), 4)                                                AS avg_spend_per_customer,
    ROUND(AVG(o.spend) FILTER (WHERE o.spend > 0), 2)                     AS avg_spend_per_buyer,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.spend)
           FILTER (WHERE o.spend > 0))::numeric, 2)                       AS median_spend_per_buyer,
    MAX(o.spend)                                                          AS max_spend
FROM assignments a
JOIN outcomes o USING (customer_id)
GROUP BY a.segment
ORDER BY CASE a.segment WHEN 'No E-Mail' THEN 0 WHEN 'Mens E-Mail' THEN 1 ELSE 2 END;
