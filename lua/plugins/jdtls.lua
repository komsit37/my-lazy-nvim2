-- java-test 0.43.1 requires org.objectweb.asm [9.9.0,9.10.0) but the current
-- jdtls build bundles asm 9.10.1, so its OSGi bundle can't resolve. jdtls keeps
-- running but logs a noisy (non-fatal) "Failed to load extension bundles"
-- warning on every java file, and the test runner can't work regardless.
-- Disable the test integration until mason's java-test catches up to asm 9.10;
-- remove this file to re-enable. Debug (java-debug-adapter) is unaffected.
return {
  {
    "mfussenegger/nvim-jdtls",
    opts = { test = false },
  },
}
