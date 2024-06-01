use cw_utils::Duration;
use voting::threshold::{PercentageThreshold, Threshold};

pub fn neta_percentage_threshold_to_v1(
    neta: voting_v1::PercentageThreshold,
) -> PercentageThreshold {
    match neta {
        voting_v1::PercentageThreshold::Majority {} => PercentageThreshold::Majority {},
        voting_v1::PercentageThreshold::Percent(p) => PercentageThreshold::Percent(p),
    }
}

pub fn neta_threshold_to_v1(neta: voting_v1::Threshold) -> Threshold {
    match neta {
        voting_v1::Threshold::AbsolutePercentage { percentage } => Threshold::AbsolutePercentage {
            percentage: neta_percentage_threshold_to_v1(percentage),
        },
        voting_v1::Threshold::ThresholdQuorum { threshold, quorum } => Threshold::ThresholdQuorum {
            threshold: neta_percentage_threshold_to_v1(threshold),
            quorum: neta_percentage_threshold_to_v1(quorum),
        },
        voting_v1::Threshold::AbsoluteCount { threshold } => Threshold::AbsoluteCount { threshold },
    }
}

pub fn neta_duration_to_v2(neta: cw_utils::Duration) -> Duration {
    match neta {
        cw_utils::Duration::Height(height) => Duration::Height(height),
        cw_utils::Duration::Time(time) => Duration::Time(time),
    }
}
