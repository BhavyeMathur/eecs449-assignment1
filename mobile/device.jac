"""Browser-preview fallbacks for device-only camera and notifications."""

import from .device_types { CapturedPhoto }

async def:pub choose_photo(source: str) -> CapturedPhoto {
    return CapturedPhoto();
}

async def:pub ensure_daily_reminder(hour: int, minute: int) -> bool {
    return False;
}
