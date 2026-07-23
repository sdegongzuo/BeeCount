package com.tntlikely.beecount.regression

enum class RegressionSampleProtection { ORDINARY, PROTECTED }

data class RegressionMigrationSampleState(
    val sampleId: String,
    val protection: RegressionSampleProtection,
    val structureFingerprint: String,
    val wasUnreadableBefore: Boolean,
    val isUnreadableNow: Boolean,
    val hasCandidateExpectedRevision: Boolean,
    val relevantPaymentMethod: Boolean,
)

enum class MigrationCoverageReasonCode {
    PROTECTED_SAMPLE_UNREADABLE,
    NEWLY_UNREADABLE_SAMPLE,
    PRE_EXISTING_UNREADABLE_ORDINARY_RATIO_EXCEEDED,
    STRUCTURE_LOST_LAST_READABLE_SAMPLE,
    EXPECTED_REVISION_COVERAGE_INCOMPLETE,
}

data class MigrationCoverageReason(
    val code: MigrationCoverageReasonCode,
    val sampleIds: List<String> = emptyList(),
    val structureFingerprints: List<String> = emptyList(),
    val affectedCount: Int = sampleIds.size,
    val totalCount: Int = 0,
)

data class MigrationCoverageResult(val reasons: List<MigrationCoverageReason>) {
    val canSwitchAutomatically: Boolean get() = reasons.isEmpty()
}

class RegressionMigrationCoveragePolicy {
    fun evaluate(samples: List<RegressionMigrationSampleState>): MigrationCoverageResult {
        val relevant = samples.filter { it.relevantPaymentMethod }
        val reasons = mutableListOf<MigrationCoverageReason>()
        val protectedUnreadable = relevant.filter {
            it.protection == RegressionSampleProtection.PROTECTED && it.isUnreadableNow
        }
        if (protectedUnreadable.isNotEmpty()) {
            reasons += MigrationCoverageReason(
                MigrationCoverageReasonCode.PROTECTED_SAMPLE_UNREADABLE,
                sampleIds = protectedUnreadable.map { it.sampleId },
            )
        }
        val newlyUnreadable = relevant.filter { !it.wasUnreadableBefore && it.isUnreadableNow }
        if (newlyUnreadable.isNotEmpty()) {
            reasons += MigrationCoverageReason(
                MigrationCoverageReasonCode.NEWLY_UNREADABLE_SAMPLE,
                sampleIds = newlyUnreadable.map { it.sampleId },
            )
        }
        val ordinary = relevant.filter {
            it.protection == RegressionSampleProtection.ORDINARY
        }
        val preExistingUnreadable = ordinary.filter {
            it.wasUnreadableBefore && it.isUnreadableNow
        }
        if (ordinary.isNotEmpty() && preExistingUnreadable.size * 100 > ordinary.size * 5) {
            reasons += MigrationCoverageReason(
                MigrationCoverageReasonCode.PRE_EXISTING_UNREADABLE_ORDINARY_RATIO_EXCEEDED,
                sampleIds = preExistingUnreadable.map { it.sampleId },
                affectedCount = preExistingUnreadable.size,
                totalCount = ordinary.size,
            )
        }
        val lostStructures = relevant.groupBy { it.structureFingerprint }
            .filterValues { group ->
                group.size > 1 &&
                    group.any { !it.wasUnreadableBefore } &&
                    group.none { !it.isUnreadableNow }
            }
            .keys.sorted()
        if (lostStructures.isNotEmpty()) {
            reasons += MigrationCoverageReason(
                MigrationCoverageReasonCode.STRUCTURE_LOST_LAST_READABLE_SAMPLE,
                structureFingerprints = lostStructures,
            )
        }
        val readable = relevant.filterNot { it.isUnreadableNow }
        val missingExpected = readable.filterNot { it.hasCandidateExpectedRevision }
        if (missingExpected.isNotEmpty()) {
            reasons += MigrationCoverageReason(
                MigrationCoverageReasonCode.EXPECTED_REVISION_COVERAGE_INCOMPLETE,
                sampleIds = missingExpected.map { it.sampleId },
                affectedCount = missingExpected.size,
                totalCount = readable.size,
            )
        }
        return MigrationCoverageResult(reasons)
    }
}
