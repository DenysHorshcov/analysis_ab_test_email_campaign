"""Synthetic simulations for the A/B method (plan step 7).

Nothing here uses real customers: every function draws random data from the
given parameters. The z-test is the same as ab_stats.two_proportion_test,
only vectorised so that thousands of experiments can be tested at once.
"""
from __future__ import annotations

import numpy as np
from scipy import stats
from statsmodels.stats.power import NormalIndPower
from statsmodels.stats.proportion import proportion_effectsize

import ab_stats as ab


def two_proportion_pvalues(x1, n1, x2, n2) -> np.ndarray:
    """Two-sided pooled z-test p-values for arrays of counts.

    Returns p = 1 where the test is undefined (no successes or no failures in
    both groups together): such data gives no evidence of a difference.
    """
    x1, n1, x2, n2 = np.broadcast_arrays(*(np.asarray(v, dtype=float) for v in (x1, n1, x2, n2)))
    pooled = (x1 + x2) / (n1 + n2)
    se = np.sqrt(pooled * (1 - pooled) * (1 / n1 + 1 / n2))
    z = np.divide(x1 / n1 - x2 / n2, se, out=np.zeros_like(se), where=se > 0)
    return 2 * stats.norm.sf(np.abs(z))


def running_pvalues(rng: np.random.Generator, p: float, batch: int, n_batches: int, n_sim: int) -> np.ndarray:
    """A/A experiments observed batch by batch.

    Both groups have the same conversion p. Element [i, j] is the p-value of
    experiment i after j + 1 batches (batch clients per group each). The last
    column is the ordinary fixed-horizon A/A test.
    """
    x1 = rng.binomial(batch, p, size=(n_sim, n_batches)).cumsum(axis=1)
    x2 = rng.binomial(batch, p, size=(n_sim, n_batches)).cumsum(axis=1)
    n = batch * np.arange(1, n_batches + 1)
    return two_proportion_pvalues(x1, n, x2, n)


def stopped_significant(p_running: np.ndarray, n_looks: int, alpha: float = 0.05) -> np.ndarray:
    """Which experiments cross p < alpha at any of n_looks evenly spaced looks.

    The last look is always the final batch.
    """
    total = p_running.shape[1]
    if n_looks < 1 or total % n_looks != 0:
        raise ValueError("n_looks must divide the number of batches")
    step = total // n_looks
    return (p_running[:, step - 1 :: step] < alpha).any(axis=1)


def false_positive_counts(p_values: np.ndarray, alpha: float = 0.05) -> dict[str, np.ndarray]:
    """Number of 'significant' metrics in each experiment (row) per correction method."""
    adjusted = {
        "raw": p_values,
        "bonferroni": np.array([ab.bonferroni(row) for row in p_values]),
        "holm": np.array([ab.holm(row) for row in p_values]),
    }
    return {name: (p < alpha).sum(axis=1) for name, p in adjusted.items()}


def analytic_power(p_base: float, uplift: float, n_per_group: int, alpha: float = 0.05) -> float:
    """Power from Cohen's h, the same formula as ab_stats.sample_size_two_proportions."""
    h = proportion_effectsize(p_base + uplift, p_base)
    return float(NormalIndPower().power(effect_size=abs(h), nobs1=n_per_group, alpha=alpha, ratio=1.0))


def empirical_power(rng: np.random.Generator, p_base: float, uplift: float, n_per_group: int,
                    n_sim: int = 10_000, alpha: float = 0.05) -> float:
    """Share of simulated experiments with a true uplift where the z-test finds p < alpha."""
    x1 = rng.binomial(n_per_group, p_base + uplift, size=n_sim)
    x2 = rng.binomial(n_per_group, p_base, size=n_sim)
    return float((two_proportion_pvalues(x1, n_per_group, x2, n_per_group) < alpha).mean())


def broken_randomization(rng: np.random.Generator, p: float, n_per_group: int, drop_share: float,
                         n_sim: int = 10_000, alpha: float = 0.05, srm_alpha: float = 0.001) -> dict[str, float]:
    """A/A experiments where the treatment group loses part of its non-buyers.

    Clients are split 50/50 at random, then each non-converter in treatment is
    lost with probability drop_share (for example, a logging bug that records
    inactive clients less often). The true effect is zero.
    """
    total = 2 * n_per_group
    assigned_t = rng.binomial(total, 0.5, size=n_sim)
    n_c = total - assigned_t
    x_t = rng.binomial(assigned_t, p)
    x_c = rng.binomial(n_c, p)
    n_t = x_t + rng.binomial(assigned_t - x_t, 1 - drop_share)

    diff = x_t / n_t - x_c / n_c
    significant = two_proportion_pvalues(x_t, n_t, x_c, n_c) < alpha
    srm_p = stats.chi2.sf((n_t - n_c) ** 2 / (n_t + n_c), df=1)
    return {
        "drop_share": drop_share,
        "mean_diff": float(diff.mean()),
        "false_win_share": float((significant & (diff > 0)).mean()),
        "significant_share": float(significant.mean()),
        "srm_detected_share": float((srm_p < srm_alpha).mean()),
    }
