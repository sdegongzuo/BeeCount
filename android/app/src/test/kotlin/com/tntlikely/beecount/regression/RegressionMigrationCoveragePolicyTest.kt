package com.tntlikely.beecount.regression

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RegressionMigrationCoveragePolicyTest {
    private val policy = RegressionMigrationCoveragePolicy()

    @Test
    fun `allows complete migration coverage`() {
        val result = policy.evaluate(
            listOf(
                sample("protected", RegressionSampleProtection.PROTECTED, "unionpay"),
                sample("ordinary", RegressionSampleProtection.ORDINARY, "wechat"),
            ),
        )

        assertTrue(result.canSwitchAutomatically)
        assertTrue(result.reasons.isEmpty())
    }

    @Test
    fun `blocks any protected sample that is currently unreadable`() {
        val result = policy.evaluate(
            listOf(
                sample(
                    id = "protected",
                    protection = RegressionSampleProtection.PROTECTED,
                    structure = "unionpay",
                    wasUnreadableBefore = true,
                    isUnreadableNow = true,
                ),
            ),
        )

        assertFalse(result.canSwitchAutomatically)
        assertEquals(
            listOf(MigrationCoverageReasonCode.PROTECTED_SAMPLE_UNREADABLE),
            result.reasons.map { it.code },
        )
        assertEquals(listOf("protected"), result.reasons.single().sampleIds)
    }

    @Test
    fun `blocks a sample that became unreadable during migration`() {
        val result = policy.evaluate(
            listOf(
                sample(
                    id = "newly-unreadable",
                    structure = "alipay",
                    wasUnreadableBefore = false,
                    isUnreadableNow = true,
                ),
            ),
        )

        assertFalse(result.canSwitchAutomatically)
        assertEquals(
            MigrationCoverageReasonCode.NEWLY_UNREADABLE_SAMPLE,
            result.reasons.single().code,
        )
    }

    @Test
    fun `allows exactly five percent pre-existing unreadable relevant ordinary samples`() {
        val samples = (1..20).map { index ->
            sample(
                id = "ordinary-$index",
                structure = "structure-$index",
                wasUnreadableBefore = index == 1,
                isUnreadableNow = index == 1,
            )
        }

        assertTrue(policy.evaluate(samples).canSwitchAutomatically)
    }

    @Test
    fun `blocks when more than five percent of relevant ordinary samples were already unreadable`() {
        val samples = (1..19).map { index ->
            sample(
                id = "ordinary-$index",
                structure = "structure-$index",
                wasUnreadableBefore = index == 1,
                isUnreadableNow = index == 1,
            )
        }

        val result = policy.evaluate(samples)

        assertFalse(result.canSwitchAutomatically)
        val reason = result.reasons.single()
        assertEquals(
            MigrationCoverageReasonCode.PRE_EXISTING_UNREADABLE_ORDINARY_RATIO_EXCEEDED,
            reason.code,
        )
        assertEquals(1, reason.affectedCount)
        assertEquals(19, reason.totalCount)
    }

    @Test
    fun `irrelevant ordinary samples do not affect unreadable ratio`() {
        val result = policy.evaluate(
            listOf(
                sample(
                    id = "irrelevant",
                    structure = "receipt",
                    wasUnreadableBefore = true,
                    isUnreadableNow = true,
                    relevantPaymentMethod = false,
                ),
                sample(id = "relevant", structure = "unionpay"),
            ),
        )

        assertTrue(result.canSwitchAutomatically)
    }

    @Test
    fun `blocks when a relevant structure loses its last readable sample`() {
        val result = policy.evaluate(
            listOf(
                sample(
                    id = "last-readable",
                    structure = "unionpay",
                    wasUnreadableBefore = false,
                    isUnreadableNow = true,
                ),
                sample(
                    id = "already-unreadable",
                    structure = "unionpay",
                    wasUnreadableBefore = true,
                    isUnreadableNow = true,
                ),
            ),
        )

        assertFalse(result.canSwitchAutomatically)
        assertTrue(
            result.reasons.any {
                it.code == MigrationCoverageReasonCode.STRUCTURE_LOST_LAST_READABLE_SAMPLE &&
                    it.structureFingerprints == listOf("unionpay")
            },
        )
    }

    @Test
    fun `does not report structure loss when another readable sample remains`() {
        val result = policy.evaluate(
            listOf(
                sample(
                    id = "failed",
                    structure = "unionpay",
                    wasUnreadableBefore = false,
                    isUnreadableNow = true,
                ),
                sample(id = "remaining", structure = "unionpay"),
            ),
        )

        assertFalse(
            result.reasons.any {
                it.code == MigrationCoverageReasonCode.STRUCTURE_LOST_LAST_READABLE_SAMPLE
            },
        )
    }

    @Test
    fun `blocks when any readable relevant sample lacks candidate expected revision`() {
        val result = policy.evaluate(
            listOf(
                sample(id = "covered", structure = "unionpay"),
                sample(
                    id = "missing",
                    structure = "wechat",
                    hasCandidateExpectedRevision = false,
                ),
            ),
        )

        assertFalse(result.canSwitchAutomatically)
        val reason = result.reasons.single()
        assertEquals(MigrationCoverageReasonCode.EXPECTED_REVISION_COVERAGE_INCOMPLETE, reason.code)
        assertEquals(listOf("missing"), reason.sampleIds)
        assertEquals(1, reason.affectedCount)
        assertEquals(2, reason.totalCount)
    }

    private fun sample(
        id: String,
        protection: RegressionSampleProtection = RegressionSampleProtection.ORDINARY,
        structure: String,
        wasUnreadableBefore: Boolean = false,
        isUnreadableNow: Boolean = false,
        hasCandidateExpectedRevision: Boolean = true,
        relevantPaymentMethod: Boolean = true,
    ) = RegressionMigrationSampleState(
        sampleId = id,
        protection = protection,
        structureFingerprint = structure,
        wasUnreadableBefore = wasUnreadableBefore,
        isUnreadableNow = isUnreadableNow,
        hasCandidateExpectedRevision = hasCandidateExpectedRevision,
        relevantPaymentMethod = relevantPaymentMethod,
    )
}
