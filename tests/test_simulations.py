import sys
from pathlib import Path

import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
import ab_stats as ab  # noqa: E402
import simulations as sim  # noqa: E402


def test_vectorised_pvalues_match_scalar_test():
    x1, x2 = np.array([560, 267, 3]), np.array([500, 122, 9])
    n1, n2 = np.array([10_000, 21_307, 50]), np.array([10_000, 21_306, 70])
    expected = [ab.two_proportion_test(*args).p_value for args in zip(x1, n1, x2, n2)]
    assert sim.two_proportion_pvalues(x1, n1, x2, n2) == pytest.approx(expected)


def test_undefined_test_gives_p_one():
    assert sim.two_proportion_pvalues([0, 10], [10, 10], [0, 10], [10, 10]) == pytest.approx([1.0, 1.0])


def test_stopped_significant_uses_evenly_spaced_looks():
    p = np.array([[0.01, 0.50, 0.50, 0.50],   # significant only after batch 1
                  [0.50, 0.01, 0.50, 0.50],   # only after batch 2
                  [0.50, 0.50, 0.50, 0.01]])  # only at the end
    assert sim.stopped_significant(p, 1).tolist() == [False, False, True]
    assert sim.stopped_significant(p, 2).tolist() == [False, True, True]
    assert sim.stopped_significant(p, 4).tolist() == [True, True, True]
    with pytest.raises(ValueError):
        sim.stopped_significant(p, 3)


def test_peeking_inflates_false_positives():
    p = sim.running_pvalues(np.random.default_rng(1), 0.01, batch=1_000, n_batches=20, n_sim=5_000)
    once = sim.stopped_significant(p, 1).mean()
    often = sim.stopped_significant(p, 20).mean()
    assert once == pytest.approx(0.05, abs=0.01)
    assert often > 3 * once


def test_false_positive_counts():
    p = np.array([[0.001, 0.02, 0.40], [0.30, 0.50, 0.90]])
    counts = sim.false_positive_counts(p)
    assert counts["raw"].tolist() == [2, 0]
    assert counts["bonferroni"].tolist() == [1, 0]  # 0.02 * 3 = 0.06
    assert counts["holm"].tolist() == [2, 0]        # 0.02 * 2 = 0.04


def test_power_at_design_sample_size_is_80_percent():
    n = ab.sample_size_two_proportions(0.00573, 0.003)
    assert sim.analytic_power(0.00573, 0.003, n) == pytest.approx(0.8, abs=0.001)
    got = sim.empirical_power(np.random.default_rng(3), 0.00573, 0.003, n, n_sim=20_000)
    assert got == pytest.approx(0.8, abs=0.02)


def test_broken_randomization():
    rng = np.random.default_rng(4)
    fine = sim.broken_randomization(rng, 0.009, 21_300, 0.0, n_sim=5_000)
    assert fine["significant_share"] == pytest.approx(0.05, abs=0.01)
    assert fine["srm_detected_share"] < 0.01
    broken = sim.broken_randomization(rng, 0.009, 21_300, 0.20, n_sim=5_000)
    assert broken["mean_diff"] > 0.001
    assert broken["false_win_share"] > 0.3
    assert broken["srm_detected_share"] > 0.99
