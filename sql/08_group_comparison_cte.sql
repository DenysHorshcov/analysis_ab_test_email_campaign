-- Питання: на скільки лист змінює visit rate, conversion rate і середні витрати порівняно з контролем,
--          і чи є різниця між чоловічим та жіночим листом (H3)?
-- Очікування: обидва листи вищі за контроль (H1, H2); різниця Mens vs Womens менша за різницю з контролем.
-- Техніки: CTE (by_group, pairs), self-join (одна й та сама by_group з двох боків порівняння).
-- Примітка: лише точкові оцінки. P-value, довірчі інтервали і поправка Holm на три порівняння: у Python.
--   Рядок 'Mens vs Womens' порівнює два листи між собою (база = Womens), а не з контролем.
-- Висновок: H1 Mens vs контроль: visit +7,66 п.п. (+72,1%), conversion +0,681 п.п. (+118,8%), середній
--   spend +0,7698 (+117,9%). H2 Womens vs контроль: visit +4,52 п.п. (+42,6%), conversion +0,311 п.п.
--   (+54,3%), spend +0,4244 (+65,0%). H3 Mens vs Womens: visit +3,14 п.п. (+20,7%), conversion
--   +0,369 п.п. (+41,8%), spend +0,3454 (+32,1%). Обидва листи вищі за контроль, чоловічий вищий
--   за жіночий за всіма трьома метриками. Значущість (з поправкою на 3 порівняння): у Python.

WITH by_group AS (
    SELECT
        a.segment,
        COUNT(*)                                          AS n,
        100.0 * AVG(o.visit::numeric)                     AS visit_rate,
        100.0 * AVG(o.conversion::numeric)                AS conv_rate,
        AVG(o.spend)                                      AS avg_spend
    FROM assignments a
    JOIN outcomes o USING (customer_id)
    GROUP BY a.segment
),
pairs (comparison, test_segment, base_segment, hypothesis) AS (
    VALUES ('Mens vs control',   'Mens E-Mail',   'No E-Mail',     'H1'),
           ('Womens vs control', 'Womens E-Mail', 'No E-Mail',     'H2'),
           ('Mens vs Womens',    'Mens E-Mail',   'Womens E-Mail', 'H3')
)
SELECT
    p.hypothesis,
    p.comparison,
    ROUND(t.visit_rate - b.visit_rate, 2)                                         AS visit_diff_pp,
    ROUND(100 * (t.visit_rate - b.visit_rate) / NULLIF(b.visit_rate, 0), 1)       AS visit_rel_lift_pct,
    ROUND(t.conv_rate - b.conv_rate, 3)                                           AS conv_diff_pp,
    ROUND(100 * (t.conv_rate - b.conv_rate) / NULLIF(b.conv_rate, 0), 1)          AS conv_rel_lift_pct,
    ROUND(t.avg_spend - b.avg_spend, 4)                                           AS avg_spend_diff,
    ROUND(100 * (t.avg_spend - b.avg_spend) / NULLIF(b.avg_spend, 0), 1)          AS avg_spend_rel_lift_pct
FROM pairs p
JOIN by_group t ON t.segment = p.test_segment
JOIN by_group b ON b.segment = p.base_segment
ORDER BY p.hypothesis;
