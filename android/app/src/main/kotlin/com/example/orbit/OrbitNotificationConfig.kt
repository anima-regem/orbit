package com.example.orbit

object OrbitNotificationConfig {
    private val lock = Any()

    // Default starter apps until user chooses from installed-app list.
    private val allowedPackages = mutableSetOf(
        "com.instagram.android",
        "com.whatsapp",
    )

    fun isAllowed(packageName: String): Boolean {
        val normalized = packageName.lowercase()
        synchronized(lock) {
            return allowedPackages.contains(normalized)
        }
    }

    fun setAllowedPackages(packages: Collection<String>) {
        val normalized = packages
            .map { it.trim().lowercase() }
            .filter { it.isNotBlank() }
            .toSet()

        synchronized(lock) {
            allowedPackages.clear()
            allowedPackages.addAll(normalized)
        }
    }

    fun snapshot(): Set<String> {
        synchronized(lock) {
            return allowedPackages.toSet()
        }
    }
}
