import os;


test "limits repeated calls from one installation" {
    reset_rate_limits_for_tests();
    os.environ["TYYLI_TEST_LIMIT_ONE"] = "2";
    enforce_device_rate_limit("device-a", "test-one", "TYYLI_TEST_LIMIT_ONE", 2);
    enforce_device_rate_limit("device-a", "test-one", "TYYLI_TEST_LIMIT_ONE", 2);
    with testraises(RuntimeError, `match="usage limit") {
        enforce_device_rate_limit("device-a", "test-one", "TYYLI_TEST_LIMIT_ONE", 2);
    }
}


test "keeps installations in separate buckets" {
    reset_rate_limits_for_tests();
    os.environ["TYYLI_TEST_LIMIT_TWO"] = "1";
    enforce_device_rate_limit("device-a", "test-two", "TYYLI_TEST_LIMIT_TWO", 1);
    enforce_device_rate_limit("device-b", "test-two", "TYYLI_TEST_LIMIT_TWO", 1);
    with testraises(RuntimeError) {
        enforce_device_rate_limit("device-a", "test-two", "TYYLI_TEST_LIMIT_TWO", 1);
    }
    with testraises(RuntimeError) {
        enforce_device_rate_limit("device-b", "test-two", "TYYLI_TEST_LIMIT_TWO", 1);
    }
}
