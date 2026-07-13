package com.tntlikely.beecount

/** Tracks share requests whose Dart coordinators are still running. */
class ShareBillingRequestTracker {
    private val active = linkedSetOf<String>()

    @Synchronized
    fun started(requestId: String) {
        active += requestId
    }

    /** Returns true when no other request still owns the shared service/engine. */
    @Synchronized
    fun finished(requestId: String?): Boolean {
        if (requestId != null) active -= requestId
        return active.isEmpty()
    }

    @Synchronized
    fun contains(requestId: String): Boolean = requestId in active

    val isEmpty: Boolean
        @Synchronized get() = active.isEmpty()
}
