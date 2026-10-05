"""Pure Daybook rules shared by the service and test suite."""

glob:pub MOMENT_KINDS: list[str] = [
         "ordinary", "food", "work", "coffee", "event", "campus", "people"
     ],
     DAILY_PROMPTS: list[str] = [
         "What made today feel like today?",
         "Capture something ordinary you might otherwise forget.",
         "What are you working on right now?",
         "What did you eat or drink that was worth remembering?",
         "Where did you spend a little time today?",
         "What surprised you today?",
         "Save one small detail from the day.",
         "What conversation stayed with you?"
     ];

def:pub prompt_for_date(day_key: str) -> str {
    checksum = sum([ord(char) for char in day_key]);
    return DAILY_PROMPTS[checksum % len(DAILY_PROMPTS)];
}

def:pub normalized_thread_names(names: list[str]) -> list[str] {
    cleaned: list[str] = [];
    seen: set[str] = set();
    for raw_name in names {
        display = " ".join(raw_name.strip().split());
        normalized = display.lower();
        if display and normalized not in seen {
            cleaned.append(display);
            seen.add(normalized);
        }
    }
    return cleaned;
}

def:pub validated_kind(kind: str) -> str {
    candidate = kind.strip().lower();
    return candidate if candidate in MOMENT_KINDS else "ordinary";
}

def:pub shifted_month(month: str, delta: int) -> str {
    try {
        year = int(month[:4]);
        month_number = int(month[5:7]) + delta;
        while month_number < 1 {
            year -= 1;
            month_number += 12;
        }
        while month_number > 12 {
            year += 1;
            month_number -= 12;
        }
        return f"{year:04d}-{month_number:02d}";
    } except Exception {
        return "1970-01";
    }
}
