import sys
from pathlib import Path

import numpy as np
import pytest
from scipy import stats
from statsmodels.stats.multitest import multipletests
from statsmodels.stats.proportion import confint_proportions_2indep, proportions_ztest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
import ab_stats as ab  # noqa: E402


def test_two_proportions_hand_calculated():
    # 5.6% vs 5.0%, n = 10 000 each.
    # pooled p = 0.053, SE = sqrt(0.053 * 0.947 * 2/10000) = 0.0031683, z = 0.006 / SE = 1.8937
    # unpooled SE = sqrt(0.056*0.944/10000 + 0.05*0.95/10000) = 0.0031680, CI = 0.006 +- 1.95996 * SE
    r = ab.two_proportion_test(560, 10_000, 500, 10_000)
    assert r.diff == pytest.approx(0.006)
    assert r.statistic == pytest.approx(1.8937, abs=1e-4)
    assert r.p_value == pytest.approx(0.0583, abs=1e-4)
    assert r.ci_low == pytest.approx(-0.000209, abs=1e-6)
    assert r.ci_high == pytest.approx(0.012209, abs=1e-6)
    assert r.relative_lift == pytest.approx(0.12)
    assert not r.significant


@pytest.mark.parametrize("x1,n1,x2,n2", [(560, 10_000, 500, 10_000), (267, 21_307, 122, 21_306), (3, 50, 9, 70)])
def test_two_proportions_matches_statsmodels(x1, n1, x2, n2):
    r = ab.two_proportion_test(x1, n1, x2, n2)
    z, p = proportions_ztest([x1, x2], [n1, n2])
    low, high = confint_proportions_2indep(x1, n1, x2, n2, compare="diff", method="wald")
    assert r.statistic == pytest.approx(z)
    assert r.p_value == pytest.approx(p)
    assert (r.ci_low, r.ci_high) == pytest.approx((low, high))


def test_two_proportions_is_antisymmetric():
    a = ab.two_proportion_test(267, 21_307, 122, 21_306)
    b = ab.two_proportion_test(122, 21_306, 267, 21_307)
    assert a.diff == pytest.approx(-b.diff)
    assert a.p_value == pytest.approx(b.p_value)


@pytest.mark.parametrize("args", [(1, 0, 1, 10), (11, 10, 1, 10), (-1, 10, 1, 10), (0, 10, 0, 10)])
def test_two_proportions_rejects_bad_input(args):
    with pytest.raises(ValueError):
        ab.two_proportion_test(*args)


def test_welch_matches_scipy():
    rng = np.random.default_rng(1)
    a, b = rng.exponential(2.0, 500), rng.exponential(1.5, 800)
    r = ab.welch_test(a, b)
    ref = stats.ttest_ind(a, b, equal_var=False)
    ci = ref.confidence_interval(0.95)
    assert r.statistic == pytest.approx(ref.statistic)
    assert r.p_value == pytest.approx(ref.pvalue)
    assert (r.ci_low, r.ci_high) == pytest.approx((ci.low, ci.high))


def test_bootstrap_is_reproducible_and_close_to_welch():
    rng = np.random.default_rng(2)
    a = rng.choice([0.0, 50.0, 100.0], p=[0.90, 0.07, 0.03], size=5_000)
    b = rng.choice([0.0, 50.0, 100.0], p=[0.94, 0.04, 0.02], size=5_000)
    first = ab.bootstrap_mean_diff_ci(a, b, n_boot=4_000, seed=7)
    assert first == ab.bootstrap_mean_diff_ci(a, b, n_boot=4_000, seed=7)
    diff, low, high = first
    welch = ab.welch_test(a, b)
    assert diff == pytest.approx(welch.diff)
    assert low < diff < high
    # large samples: percentile bootstrap should be close to the t interval
    width = welch.ci_high - welch.ci_low
    assert low == pytest.approx(welch.ci_low, abs=0.1 * width)
    assert high == pytest.approx(welch.ci_high, abs=0.1 * width)


def test_bootstrap_constant_groups():
    assert ab.bootstrap_mean_diff_ci([2.0] * 10, [1.0] * 10, n_boot=100) == (1.0, 1.0, 1.0)


def test_holm_and_bonferroni_hand_calculated():
    p = [0.01, 0.04, 0.03]
    # Holm: 0.01*3 = 0.03; 0.03*2 = 0.06; 0.04*1 = 0.04 -> raised to 0.06
    assert ab.holm(p) == pytest.approx([0.03, 0.06, 0.06])
    assert ab.bonferroni(p) == pytest.approx([0.03, 0.12, 0.09])


@pytest.mark.parametrize("p", [[0.001, 0.2, 0.04], [0.5, 0.6, 0.9], [0.02, 0.02, 0.02, 0.3]])
def test_adjustments_match_statsmodels(p):
    assert ab.holm(p) == pytest.approx(multipletests(p, method="holm")[1])
    assert ab.bonferroni(p) == pytest.approx(multipletests(p, method="bonferroni")[1])


def test_sample_size_and_mde_are_consistent():
    n = ab.sample_size_two_proportions(0.00573, 0.003)
    assert ab.mde_two_proportions(n, 0.00573) == pytest.approx(0.003, rel=1e-3)
    assert ab.sample_size_two_proportions(0.00573, 0.003, alpha=0.05 / 3) > n


def test_net_revenue():
    assert ab.net_revenue_per_1000(0.77, 0.10) == pytest.approx(670.0)
