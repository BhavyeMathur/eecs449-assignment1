"""Daybook web application entry point."""

import from core.journal {
    MomentView, IntentionView, DayView, ThreadView, CalendarCell,
    JournalSnapshot, create_moment, delete_intention, delete_moment, get_day,
    get_photo_data, get_snapshot, set_intention, shift_month, seed_demo,
    toggle_intention
}
import from .App { DaybookApp }
import "./styles.css";

def:pub app -> JsxElement {
    <DaybookApp/>
}
