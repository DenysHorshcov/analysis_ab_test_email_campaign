"""Statistical functions for the A/B analysis (see docs/experiment_design.md).

Convention everywhere: group 1 is the treatment, group 2 is the baseline,
and every difference is "group 1 minus group 2". All tests are two-sided.
"""
from __future__ import annotations

from dataclasses import dataclass

import numpy as np
from scipy import stats
from statsmodels.stats.power import NormalIndPower
from statsmodels.stats.proportion import proportion_effectsize


@dataclass(frozen=True)
class TestResult:
    """Difference between two groups with its confidence interval and p-value."""

    estimate1: float
    estimate2: float
    diff: float
    ci_low: float
    ci_high: float
    statistic: float
    p_value: float
    alpha: float = 0.05

    @property
    def relative_lift(self) -> float:
        """diff / baseline; NaN when the baseline is zero."""
        return self.diff / self.estimate2 if self.estimate2 != 0 else float("nan")

    @property
    def significant(self) -> bool:
        """Raw (unadjusted) significance at alpha."""
        return bool(self.p_value < self.alpha)


def two_proportion_test(x1: int, n1: int, x2: int, n2: int, alpha: float = 0.05) -> TestResult:
    """z-test for the difference of two proportions p1 - p2.

    The z statistic uses the pooled standard error (valid under H0: p1 = p2).
    The confidence interval is the Wald interval with the unpooled standard error.
    """
    for x, n in ((x1, n1), (x2, n2)):
        if n <= 0 or not 0 <= x <= n:
            raise ValueError("need n > 0 and 0 <= x <= n")
    p1, p2 = x1 / n1, x2 / n2
    diff = p1 - p2

    pooled = (x1 + x2) / (n1 + n2)
    se_pooled = np.sqrt(pooled * (1 - pooled) * (1 / n1 + 1 / n2))
    if se_pooled == 0:
        raise ValueError("z-test is undefined when all outcomes are identical")
    z = diff / se_pooled
    p_value = 2 * stats.norm.sf(abs(z))

    se = np.sqrt(p1 * (1 - p1) / n1 + p2 * (1 - p2) / n2)
    margin = stats.norm.ppf(1 - alpha / 2) * se
    return TestResult(p1, p2, diff, diff - margin, diff + margin, float(z), float(p_value), alpha)


def welch_test(a, b, alpha: float = 0.05) -> TestResult:
    """Welch t-test (unequal variances) for the difference of means a - b."""
    a, b = np.asarray(a, dtype=float), np.asarray(b, dtype=float)
    if len(a) < 2 or len(b) < 2:
        raise ValueError("each group needs at least two observations")
    v1, v2 = a.var(ddof=1) / len(a), b.var(ddof=1) / len(b)
    se = np.sqrt(v1 + v2)
    if se == 0:
        raise ValueError("t-test is undefined when both groups are constant")
    diff = a.mean() - b.mean()
    t = diff / se
    df = (v1 + v2) ** 2 / (v1**2 / (len(a) - 1) + v2**2 / (len(b) - 1))
    p_value = 2 * stats.t.sf(abs(t), df)
    margin = stats.t.ppf(1 - alpha / 2, df) * se
    return TestResult(a.mean(), b.mean(), diff, diff - margin, diff + margin, float(t), float(p_value), alpha)


def mann_whitney_p(a, b) -> float:
    """Two-sided Mann-Whitney U p-value (check that does not rely on the means)."""
    return float(stats.mannwhitneyu(a, b, alternative="two-sided").pvalue)


def _bootstrap_means(x: np.ndarray, n_boot: int, rng: np.random.Generator) -> np.ndarray:
    # Drawing n values with replacement equals drawing multinomial counts over the
    # unique values. It is the same bootstrap, but fast for data that is mostly zeros.
    values, counts = np.unique(x, return_counts=True)
    draws = rng.multinomial(len(x), counts / len(x), size=n_boot)
    return draws @ values / len(x)


def bootstrap_mean_diff_ci(a, b, n_boot: int = 10_000, alpha: float = 0.05, seed: int = 42) -> tuple[float, float, float]:
    """Percentile bootstrap CI for mean(a) - mean(b). Returns (diff, ci_low, ci_high)."""
    a, b = np.asarray(a, dtype=float), np.asarray(b, dtype=float)
    if len(a) == 0 or len(b) == 0:
        raise ValueError("groups must not be empty")
    rng = np.random.default_rng(seed)
    boot = _bootstrap_means(a, n_boot, rng) - _bootstrap_means(b, n_boot, rng)
    low, high = np.quantile(boot, [alpha / 2, 1 - alpha / 2])
    return float(a.mean() - b.mean()), float(low), float(high)


def bonferroni(p_values) -> np.ndarray:
    """Bonferroni-adjusted p-values: p * m, capped at 1."""
    p = np.asarray(p_values, dtype=float)
    return np.minimum(p * len(p), 1.0)


def holm(p_values) -> np.ndarray:
    """Holm step-down adjusted p-values, returned in the original order."""
    p = np.asarray(p_values, dtype=float)
    m = len(p)
    order = np.argsort(p)
    stepped = p[order] * (m - np.arange(m))                     # smallest p times m, next times m-1, ...
    adjusted_sorted = np.minimum(np.maximum.accumulate(stepped), 1.0)  # keep monotone
    adjusted = np.empty(m)
    adjusted[order] = adjusted_sorted
    return adjusted


def sample_size_two_proportions(p_base: float, uplift: float, alpha: float = 0.05, power: float = 0.8) -> int:
    """Clients per group needed to detect p_base -> p_base + uplift (equal groups, Cohen's h)."""
    h = proportion_effectsize(p_base + uplift, p_base)
    n = NormalIndPower().solve_power(effect_size=abs(h), alpha=alpha, power=power, ratio=1.0)
    return int(np.ceil(n))


def mde_two_proportions(n_per_group: int, p_base: float, alpha: float = 0.05, power: float = 0.8) -> float:
    """Minimum detectable absolute increase over p_base with n clients per group."""
    h = NormalIndPower().solve_power(effect_size=None, nobs1=n_per_group, alpha=alpha, power=power, ratio=1.0)
    p_new = np.sin(np.arcsin(np.sqrt(p_base)) + h / 2) ** 2      # invert Cohen's h
    return float(p_new - p_base)


def net_revenue_per_1000(spend_diff_per_recipient: float, email_cost: float) -> float:
    """Extra revenue minus cost for 1000 recipients. Revenue only: margin is unknown."""
    return 1000 * (spend_diff_per_recipient - email_cost)
