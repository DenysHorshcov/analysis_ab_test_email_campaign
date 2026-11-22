-- Питання: на якому кроці воронки "отримав лист -> зайшов на сайт -> купив" ми втрачаємо клієнтів і чи
--          відрізняється це між групами?
-- Очікування: з отримавших лише ~10-18% заходять, з тих, хто зайшов, купує ще менша частка; контроль
--             (No E-Mail) слугує базовим рівнем.
-- Техніки: CTE, умовні лічильники (COUNT FILTER), різниця з контролем.
-- Примітка: у даних немає дат і подій, тому це воронка з 3 кроків за прапорцями, а не воронка по днях.
--   У контролі "отримали" = клієнти без листа (потрапили у вибірку), "зайшли"/"купили" з outcomes.
-- Висновок: контроль: 21 306 -> 2 262 візитів (10,62%) -> 122 покупки (5,39% з тих, хто зайшов; 0,573%
--   від усіх). Mens: 21 307 -> 3 894 (18,28%, +7,66 п.п.) -> 267 (6,86%, +1,46 п.п.; 1,253% від усіх).
--   Womens: 21 387 -> 3 238 (15,14%, +4,52 п.п.) -> 189 (5,84%, +0,44 п.п.; 0,884% від усіх).
--   Найбільші втрати на кроці "отримав -> зайшов" (82-89% не заходять), далі з відвідувачів купує
--   лише 5-7%. Обидва листи піднімають крок візиту; у Mens також трохи вищий крок "візит -> покупка".

WITH funnel AS (
    SELECT
        a.segment,
        COUNT(*)                                  AS recipients,
        COUNT(*) FILTER (WHERE o.visit = 1)       AS visited,
        COUNT(*) FILTER (WHERE o.conversion = 1)  AS purchased
    FROM assignments a
    JOIN outcomes o USING (customer_id)
    GROUP BY a.segment
),
rates AS (
    SELECT *,
           100.0 * visited   / NULLIF(recipients, 0) AS recipient_to_visit,
           100.0 * purchased / NULLIF(visited, 0)    AS visit_to_purchase,
           100.0 * purchased / NULLIF(recipients, 0) AS purchase_per_recipient
    FROM funnel
),
control AS (
    SELECT recipient_to_visit AS c_r2v, visit_to_purchase AS c_v2p, purchase_per_recipient AS c_ppr
    FROM rates
    WHERE segment = 'No E-Mail'
)
SELECT
    r.segment,
    r.recipients,
    r.visited,
    r.purchased,
    ROUND(r.recipient_to_visit, 2)                                      AS recipient_to_visit_pct,
    ROUND(r.visit_to_purchase, 2)                                       AS visit_to_purchase_pct,
    ROUND(r.purchase_per_recipient, 3)                                  AS purchase_per_recipient_pct,
    CASE WHEN r.segment = 'No E-Mail' THEN NULL
         ELSE ROUND(r.recipient_to_visit - c.c_r2v, 2) END             AS visit_step_diff_vs_control_pp,
    CASE WHEN r.segment = 'No E-Mail' THEN NULL
         ELSE ROUND(r.visit_to_purchase - c.c_v2p, 2) END              AS purchase_step_diff_vs_control_pp
FROM rates r
CROSS JOIN control c
ORDER BY CASE r.segment WHEN 'No E-Mail' THEN 0 WHEN 'Mens E-Mail' THEN 1 ELSE 2 END;
