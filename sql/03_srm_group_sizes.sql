-- Питання: чи рівномірно клієнти розподілились по групах (SRM, sample ratio mismatch)?
-- Очікування: ~33,3% у кожній групі (рандомізація 1/3 : 1/3 : 1/3).
-- Техніки: GROUP BY, віконна SUM() OVER ().
-- Примітка: SQL дає лише цифри; формальний chi-square тест на SRM робимо в Python (notebooks/01_eda.ipynb).
-- Висновок: Mens 21 307 (33,29%), No E-Mail 21 306 (33,29%), Womens 21 387 (33,42%); очікувалось 21 333,3
--   на групу. Відхилення від 1/3: -0,04, -0,04 і +0,08 п.п. (від -27 до +54 клієнтів). Групи майже
--   рівні, SRM не видно. Формальний chi-square підтвердимо в Python.

SELECT
    segment,
    COUNT(*)                                                        AS n,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)              AS share_pct,
    ROUND(SUM(COUNT(*)) OVER ()::numeric / 3, 1)                    AS expected_n,
    COUNT(*) - ROUND(SUM(COUNT(*)) OVER ()::numeric / 3, 1)         AS diff,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () - 100.0 / 3, 2)  AS diff_pp_from_one_third
FROM assignments
GROUP BY segment
ORDER BY segment;
