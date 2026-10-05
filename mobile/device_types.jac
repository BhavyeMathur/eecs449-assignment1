"""Values returned by Daybook's platform-specific integrations."""

obj:pub CapturedPhoto {
    has uri: str = "", base64_data: str = "",
        mime_type: str = "image/jpeg", cancelled: bool = True;
}
