-- Питання: яка частка клієнтів зайшла на сайт і яка купила в кожній групі, і чим це відрізняється від контролю?
-- Очікування: контроль (No E-Mail): 122 покупки, конверсія ≈ 0,573%, visit ≈ 10,6%; усього покупців ≈ 578.
-- Техніки: умовна агрегація (COUNT FILTER), CASE WHEN, CTE.
-- Примітка: лише точкові оцінки; p-value і довірчі інтервали рахуємо в Python.
-- Висновок: контроль: visit 10,62%, конверсія 0,573% (122 покупки з 21 306). Mens: visit 18,28%
--   (+7,66 п.п.), конверсія 1,253% (267 покупок): +0,681 п.п., +118,8% відносно контролю.
--   Womens: visit 15,14% (+4,52 п.п.), конверсія 0,884% (189 покупок): +0,311 п.п., +54,3%.
--   Покупців усього 578. Обидва листи вищі за контроль, чоловічий сильніший. Чи значущо це,
--   покаже Python (z-тест, ДІ, поправка Holm).

WITH by_group AS (
    SELECT
        a.segment,
        COUNT(*)                                  AS n,
        COUNT(*) FILTER (WHERE o.visit = 1)       AS visits,
        COUNT(*) FILTER (WHERE o.conversion = 1)  AS buyers
    FROM assignments a
    JOIN outcomes o USING (customer_id)
    GROUP BY a.segment
),
rates AS (
    SELECT *,
           100.0 * visits / NULLIF(n, 0) AS visit_rate,
           100.0 * buyers / NULLIF(n, 0) AS conv_rate
    FROM by_group
),
control AS (  -- контроль береться запитом, не числом
    SELECT visit_rate AS c_visit_rate, conv_rate AS c_conv_rate
    FROM rates
    WHERE segment = 'No E-Mail'
)
SELECT
    r.segment,
    r.n,
    r.visits,
    ROUND(r.visit_rate, 2)                                         AS visit_rate_pct,
    r.buyers,
    ROUND(r.conv_rate, 3)                                          AS conversion_rate_pct,
    CASE WHEN r.segment = 'No E-Mail' THEN NULL
         ELSE ROUND(r.conv_rate - c.c_conv_rate, 3) END            AS conv_diff_vs_control_pp,
    CASE WHEN r.segment = 'No E-Mail' THEN NULL
         ELSE ROUND(100.0 * (r.conv_rate - c.c_conv_rate) / NULLIF(c.c_conv_rate, 0), 1) END AS conv_rel_lift_pct,
    CASE WHEN r.segment = 'No E-Mail' THEN NULL
         ELSE ROUND(r.visit_rate - c.c_visit_rate, 2) END          AS visit_diff_vs_control_pp
FROM rates r
CROSS JOIN control c
ORDER BY CASE r.segment WHEN 'No E-Mail' THEN 0 WHEN 'Mens E-Mail' THEN 1 ELSE 2 END;
