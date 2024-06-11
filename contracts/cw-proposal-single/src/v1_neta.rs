use cw20::Expiration;
use cw_utils::Duration;
use voting::{status::Status, threshold::{PercentageThreshold, Threshold}, voting::Votes};

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

pub fn neta_duration_to_v1(neta: cw_utils::Duration) -> Duration {
    match neta {
        cw_utils::Duration::Height(height) => Duration::Height(height),
        cw_utils::Duration::Time(time) => Duration::Time(time),
    }
}

pub fn neta_expiration_to_v1(v1: cw_utils::Expiration) -> Expiration {
    match v1 {
        cw_utils::Expiration::AtHeight(height) => Expiration::AtHeight(height),
        cw_utils::Expiration::AtTime(time) => Expiration::AtTime(time),
        cw_utils::Expiration::Never {} => Expiration::Never {},
    }
}


pub fn neta_status_to_v1(v1: voting_v1::Status) -> Status {
    match v1 {
        voting_v1::Status::Open => Status::Open,
        voting_v1::Status::Rejected => Status::Rejected,
        voting_v1::Status::Passed => Status::Passed,
        voting_v1::Status::Executed => Status::Executed,
        voting_v1::Status::Closed => Status::Closed,
    }
}

pub fn neta_votes_to_v1(v1: voting_v1::Votes) -> Votes {
    Votes {
        yes: v1.yes,
        no: v1.no,
        abstain: v1.abstain,
    }
}