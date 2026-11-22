-- Питання: чи відрізняється результат розсилки в різних типах клієнтів?
-- ДОСЛІДНИЦЬКИЙ аналіз: це гіпотези для наступного тесту, а не висновки і не частина критерію рішення
-- (багато розрізів = множинні порівняння). Причинний висновок тут можливий лише про ефект листа загалом.
-- Очікування: у більшості розрізів порядок груп той самий, що й в цілому (Mens > Womens > контроль);
--             у малих підгрупах (n < 500) цифри нестабільні.
-- Техніки: GROUP BY кількох полів, CASE (діапазони recency), UNION ALL розрізів, прапорець надійності.
-- Примітка: 'Surburban' у zip_code лишається як в оригіналі.
-- Висновок: 33 рядки (4 розрізи x 3 групи), найменша підгрупа n = 2 577, ненадійних (n<500) немає,
--   але покупців у клітинках лише 18-148, тож оцінки шумні. В усіх 11 значеннях розрізів порядок
--   conversion той самий, що й загалом: Mens > Womens > контроль. Помітно: серед нових клієнтів
--   контроль майже не купує (0,374% проти 0,773% у існуючих), тому лист там дає більший приріст
--   (Womens 0,901%, Mens 1,114%); у Multichannel конверсія вища в усіх групах (Mens 1,707%).
--   Це гіпотези для наступного тесту, не підтверджені висновки.

WITH base AS (
    SELECT
        a.segment,
        CASE WHEN c.newbie = 1 THEN 'new' ELSE 'existing' END                    AS newbie,
        c.channel,
        c.zip_code,
        CASE WHEN c.recency <= 3 THEN '1) 1-3'
             WHEN c.recency <= 6 THEN '2) 4-6'
             ELSE '3) 7-12' END                                                  AS recency_band,
        o.conversion,
        o.spend
    FROM assignments a
    JOIN customers c USING (customer_id)
    JOIN outcomes  o USING (customer_id)
),
long AS (  -- один формат для всіх розрізів
    SELECT 'newbie'       AS dimension, newbie       AS value, segment, conversion, spend FROM base
    UNION ALL SELECT 'channel',      channel,      segment, conversion, spend FROM base
    UNION ALL SELECT 'zip_code',     zip_code,     segment, conversion, spend FROM base
    UNION ALL SELECT 'recency_band', recency_band, segment, conversion, spend FROM base
)
SELECT
    dimension,
    value,
    segment,
    COUNT(*)                                                      AS n,
    SUM(conversion)                                               AS buyers,
    ROUND(100.0 * SUM(conversion) / NULLIF(COUNT(*), 0), 3)       AS conversion_rate_pct,
    ROUND(AVG(spend), 3)                                          AS avg_spend,
    CASE WHEN COUNT(*) < 500 THEN 'UNRELIABLE (n<500)' ELSE 'ok' END AS reliability
FROM long
GROUP BY dimension, value, segment
ORDER BY dimension, value,
         CASE segment WHEN 'No E-Mail' THEN 0 WHEN 'Mens E-Mail' THEN 1 ELSE 2 END;
