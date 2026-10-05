"""Pure behavior tests for Daybook normalization and calendar helpers."""

import from core.rules {
    normalized_thread_names, prompt_for_date, shifted_month, validated_kind
}

test "thread names are normalized and deduplicated" {
    assert normalized_thread_names([
        "  Coffee   Chats ", "coffee chats", "Research"
    ]) == ["Coffee Chats", "Research"];
}

test "unknown kinds become ordinary" {
    assert validated_kind("mystery") == "ordinary";
    assert validated_kind(" WORK ") == "work";
}

test "daily prompts are deterministic" {
    assert prompt_for_date("2026-09-14") == prompt_for_date("2026-09-14");
}

test "month shifting crosses year boundaries" {
    assert shifted_month("2026-01", -1) == "2025-12";
    assert shifted_month("2026-12", 1) == "2027-01";
}
