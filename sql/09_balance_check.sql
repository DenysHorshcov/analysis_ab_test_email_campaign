-- Питання: чи схожі три групи за характеристиками клієнтів ДО листа (чи справді рандомізація спрацювала)?
-- Очікування: розподіли майже однакові в усіх групах; max_diff_pp (найбільша різниця часток між групами)
--             близько нуля, середні recency/history майже збігаються.
-- Техніки: умовна агрегація (FILTER), CASE, pivot (групи в колонках), UNION ALL.
-- Примітка: SQL дає лише різниці. SMD (стандартизована різниця) і chi-square/t-test: у Python (01_eda.ipynb).
--   'Surburban' у zip_code лишається як в оригіналі. Для mens/womens береться частка клієнтів зі значенням 1.
-- Висновок: групи дуже схожі. recency: середнє 5,750 / 5,774 / 5,768, стд 3,50-3,51. history: середнє
--   240,88 / 242,84 / 242,54 (різниця 1,95 при середньому ~242), стд 252,7-260,4. Частки категорій
--   відрізняються не більше ніж на 0,84 п.п. (найбільше: channel Phone 43,78% / 43,37% / 44,20%);
--   newbie 50,20 / 50,15 / 50,32%, mens 55,3 / 55,1 / 54,9%, womens 54,8 / 55,1 / 55,0%. Системного
--   зсуву не видно, рандомізація виглядає коректною. Формальні тести (SMD, chi-square): у Python.

WITH base AS (
    SELECT a.segment, c.recency, c.history, c.mens, c.womens, c.newbie,
           c.channel, c.zip_code, c.history_segment
    FROM assignments a
    JOIN customers c USING (customer_id)
),
numeric_part AS (
    SELECT variable, stat,
           ROUND(v_control, 3) AS no_email, ROUND(v_mens, 3) AS mens_email, ROUND(v_womens, 3) AS womens_email,
           ROUND(GREATEST(v_control, v_mens, v_womens) - LEAST(v_control, v_mens, v_womens), 3) AS max_diff,
           'value' AS unit
    FROM (
        SELECT 'recency' AS variable, 'mean' AS stat,
               AVG(recency) FILTER (WHERE segment = 'No E-Mail')     AS v_control,
               AVG(recency) FILTER (WHERE segment = 'Mens E-Mail')   AS v_mens,
               AVG(recency) FILTER (WHERE segment = 'Womens E-Mail') AS v_womens
        FROM base
        UNION ALL
        SELECT 'recency', 'stddev',
               STDDEV(recency) FILTER (WHERE segment = 'No E-Mail'),
               STDDEV(recency) FILTER (WHERE segment = 'Mens E-Mail'),
               STDDEV(recency) FILTER (WHERE segment = 'Womens E-Mail')
        FROM base
        UNION ALL
        SELECT 'history', 'mean',
               AVG(history) FILTER (WHERE segment = 'No E-Mail'),
               AVG(history) FILTER (WHERE segment = 'Mens E-Mail'),
               AVG(history) FILTER (WHERE segment = 'Womens E-Mail')
        FROM base
        UNION ALL
        SELECT 'history', 'stddev',
               STDDEV(history) FILTER (WHERE segment = 'No E-Mail'),
               STDDEV(history) FILTER (WHERE segment = 'Mens E-Mail'),
               STDDEV(history) FILTER (WHERE segment = 'Womens E-Mail')
        FROM base
    ) s
),
long AS (  -- категоріальні змінні в одному форматі
    SELECT 'newbie' AS variable, newbie::text AS level, segment FROM base
    UNION ALL SELECT 'channel',         channel,         segment FROM base
    UNION ALL SELECT 'zip_code',        zip_code,        segment FROM base
    UNION ALL SELECT 'history_segment', history_segment, segment FROM base
    UNION ALL SELECT 'mens',            mens::text,      segment FROM base
    UNION ALL SELECT 'womens',          womens::text,    segment FROM base
),
shares AS (  -- pivot: частка рівня всередині кожної групи
    SELECT variable, level,
           100.0 * COUNT(*) FILTER (WHERE segment = 'No E-Mail')     / SUM(COUNT(*) FILTER (WHERE segment = 'No E-Mail'))     OVER (PARTITION BY variable) AS v_control,
           100.0 * COUNT(*) FILTER (WHERE segment = 'Mens E-Mail')   / SUM(COUNT(*) FILTER (WHERE segment = 'Mens E-Mail'))   OVER (PARTITION BY variable) AS v_mens,
           100.0 * COUNT(*) FILTER (WHERE segment = 'Womens E-Mail') / SUM(COUNT(*) FILTER (WHERE segment = 'Womens E-Mail')) OVER (PARTITION BY variable) AS v_womens
    FROM long
    GROUP BY variable, level
),
categorical_part AS (
    SELECT variable, level AS stat,
           ROUND(v_control, 2), ROUND(v_mens, 2), ROUND(v_womens, 2),
           ROUND(GREATEST(v_control, v_mens, v_womens) - LEAST(v_control, v_mens, v_womens), 2),
           'pct' AS unit
    FROM shares
    WHERE NOT (variable IN ('mens','womens','newbie') AND level = '0')  -- для бінарних лишаємо частку 1
)
SELECT * FROM numeric_part
UNION ALL
SELECT * FROM categorical_part
ORDER BY 1, 2;
