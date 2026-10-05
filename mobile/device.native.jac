"""Native Expo photo-picker and once-daily reminder integration."""

import from "expo-image-picker" {
    launchCameraAsync, launchImageLibraryAsync,
    requestCameraPermissionsAsync, requestMediaLibraryPermissionsAsync
}
import from "expo-notifications" {
    getAllScheduledNotificationsAsync, getPermissionsAsync,
    requestPermissionsAsync, scheduleNotificationAsync,
    SchedulableTriggerInputTypes
}
import from .device_types { CapturedPhoto }

async def:pub choose_photo(source: str) -> CapturedPhoto {
    if source == "camera" {
        permission = await requestCameraPermissionsAsync();
        if not permission.granted { return CapturedPhoto(); }
        result = await launchCameraAsync(
            {"mediaTypes": ["images"], "quality": 0.65, "base64": True}
        );
    } else {
        permission = await requestMediaLibraryPermissionsAsync();
        if not permission.granted { return CapturedPhoto(); }
        result = await launchImageLibraryAsync(
            {"mediaTypes": ["images"], "quality": 0.65, "base64": True}
        );
    }
    if result.canceled or not result.assets { return CapturedPhoto(); }
    asset = result.assets[0];
    return CapturedPhoto(
        uri=str(asset.uri or ""), base64_data=str(asset.base64 or ""),
        mime_type=str(asset.mimeType or "image/jpeg"), cancelled=False
    );
}

async def:pub ensure_daily_reminder(hour: int, minute: int) -> bool {
    permission = await getPermissionsAsync();
    if not permission.granted { permission = await requestPermissionsAsync(); }
    if not permission.granted { return False; }
    existing = await getAllScheduledNotificationsAsync();
    for item in existing {
        if item.content and item.content.data and item.content.data.daybookDaily {
            return True;
        }
    }
    await scheduleNotificationAsync({
        "content": {
            "title": "A moment from today",
            "body": "Take one photo of something worth remembering.",
            "data": {"daybookDaily": True}
        },
        "trigger": {
            "type": SchedulableTriggerInputTypes.DAILY,
            "hour": hour, "minute": minute
        }
    });
    return True;
}
