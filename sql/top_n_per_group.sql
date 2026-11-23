-- Питання: хто 10 найбільших покупців у кожній групі?
-- Очікування: 30 рядків (3 групи x 10); у всіх групах є покупки на максимальну суму 499.
-- Техніки: ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...), top-N на групу через підзапит/CTE.
-- Примітка: ROW_NUMBER дає унікальний номер навіть при однакових spend, тому додано другий ключ
--   сортування customer_id (інакше порядок серед рівних значень не детермінований).
--   Для порівняння: RANK дав би однаковий ранг рівним spend і рядків могло б бути більше 10 на групу.
-- Висновок: 30 рядків. Максимум 499,00 у всіх групах, але кількість таких покупців різна: контроль 2,
--   Mens 6, Womens 4 (тому тай-брейк по customer_id потрібен). 10-й за величиною: 248,04 (контроль),
--   397,32 (Mens), 350,17 (Womens). Топ-покупці з усіх каналів і з усіх сегментів history_segment, зокрема
--   з '$0 - $100': велика покупка не залежить від попередньої історії.

WITH ranked AS (
    SELECT
        a.segment,
        o.customer_id,
        o.spend,
        c.channel,
        c.history_segment,
        ROW_NUMBER() OVER (PARTITION BY a.segment ORDER BY o.spend DESC, o.customer_id) AS rn
    FROM assignments a
    JOIN outcomes  o USING (customer_id)
    JOIN customers c USING (customer_id)
    WHERE o.spend > 0
)
SELECT segment, rn AS rank_in_group, customer_id, spend, channel, history_segment
FROM ranked
WHERE rn <= 10
ORDER BY CASE segment WHEN 'No E-Mail' THEN 0 WHEN 'Mens E-Mail' THEN 1 ELSE 2 END, rn;
