"""Persistent graph and public API for Daybook.

The service owns all durable journal state. Web, mobile, and CLI apps cross
this boundary only through typed view objects and public functions. Original
photo bytes live in the file store; graph nodes retain storage metadata.
"""

import base64;
import calendar;
import datetime;
import io;
import from uuid { uuid4 }
import from .rules {
    MOMENT_KINDS, normalized_thread_names, prompt_for_date, shifted_month,
    validated_kind
}

glob PHOTO_STORE: any = store(base_path="./uploads"),
     THREAD_COLORS: list[str] = [
         "#e76f51", "#2a9d8f", "#577590", "#f4a261", "#8f6aa8", "#6a994e"
     ];

obj:pub MomentView {
    has id: str = "", caption: str = "", kind: str = "ordinary",
        captured_at: str = "", local_date: str = "", photo_url: str = "",
        thread_names: list[str] = [];
}

obj:pub IntentionView {
    has id: str = "", text: str = "", target_date: str = "",
        completed: bool = False;
}

obj:pub DayView {
    has date: str = "", prompt: str = "", moment_count: int = 0,
        photo_count: int = 0, cover_photo_url: str = "",
        moments: list[MomentView] = [], intention: IntentionView = IntentionView();
}

obj:pub ThreadView {
    has id: str = "", name: str = "", color: str = "#577590",
        moment_count: int = 0, cover_photo_url: str = "",
        moments: list[MomentView] = [];
}

obj:pub CalendarCell {
    has date: str = "", day_number: int = 0, in_month: bool = False,
        moment_count: int = 0, cover_photo_url: str = "",
        has_intention: bool = False, intention_completed: bool = False;
}

obj:pub JournalSnapshot {
    has month: str = "", month_label: str = "", today: str = "",
        total_moments: int = 0, total_photos: int = 0,
        total_intentions: int = 0, completed_intentions: int = 0,
        days: list[DayView] = [], threads: list[ThreadView] = [],
        calendar: list[CalendarCell] = [];
}

node Day {
    has date: str = "", prompt: str = "";

    def to_view -> DayView {
        moment_views = [moment.to_view() for moment in [self ->:Contains:->]];
        intentions = [intention.to_view() for intention in [self ->:Plans:->]];
        moment_views.sort(
            key=lambda (item: MomentView) { item.captured_at; }, reverse=True
        );
        photos = [item.photo_url for item in moment_views if item.photo_url];
        return DayView(
            date=self.date, prompt=self.prompt, moment_count=len(moment_views),
            photo_count=len(photos), cover_photo_url=photos[0] if photos else "",
            moments=moment_views,
            intention=intentions[0] if intentions else IntentionView()
        );
    }
}

node Intention {
    has text: str = "", target_date: str = "", completed: bool = False;

    def to_view -> IntentionView {
        return IntentionView(
            id=jid(self), text=self.text, target_date=self.target_date,
            completed=self.completed
        );
    }
}

node Moment {
    has caption: str = "", kind: str = "ordinary", captured_at: str = "",
        local_date: str = "", photo_path: str = "", photo_mime: str = "";

    def to_view -> MomentView {
        linked_threads = [thread.name for thread in [self ->:InThread:->]];
        linked_threads.sort();
        return MomentView(
            id=jid(self), caption=self.caption, kind=self.kind,
            captured_at=self.captured_at, local_date=self.local_date,
            photo_url=f"/media/{jid(self)}" if self.photo_path else "",
            thread_names=linked_threads
        );
    }
}

node Thread {
    has name: str = "", normalized_name: str = "", color: str = "#577590";

    def to_view -> ThreadView {
        moment_views = [moment.to_view() for moment in [self <-:InThread:<-]];
        moment_views.sort(
            key=lambda (item: MomentView) { item.captured_at; }, reverse=True
        );
        photos = [item.photo_url for item in moment_views if item.photo_url];
        return ThreadView(
            id=jid(self), name=self.name, color=self.color,
            moment_count=len(moment_views),
            cover_photo_url=photos[0] if photos else "", moments=moment_views
        );
    }
}

edge Contains: Day --> Moment {}
edge InThread: Moment --> Thread {}
edge Plans: Day --> Intention {}

def now_iso -> str {
    return datetime.datetime.now(datetime.timezone.utc).isoformat();
}

def today_key -> str {
    return datetime.date.today().isoformat();
}

def resolved_date(day_key: str) -> str {
    candidate = day_key.strip();
    if not candidate {
        return today_key();
    }
    try {
        datetime.date.fromisoformat(candidate);
    } except Exception {
        raise ValueError("Dates must use YYYY-MM-DD");
    }
    return candidate;
}

def get_or_create_day(day_key: str) -> Day {
    matches = [root-->[?:Day, date == day_key]];
    if matches {
        return matches[0];
    }
    return root ++> Day(date=day_key, prompt=prompt_for_date(day_key));
}

def get_or_create_thread(name: str) -> Thread {
    normalized = name.lower();
    matches = [root-->[?:Thread, normalized_name == normalized]];
    if matches {
        return matches[0];
    }
    color = THREAD_COLORS[len([root-->[?:Thread]]) % len(THREAD_COLORS)];
    return root ++> Thread(name=name, normalized_name=normalized, color=color);
}

def owns_day(day: Day) -> bool {
    for candidate in [root-->[?:Day]] {
        if jid(candidate) == jid(day) {
            return True;
        }
    }
    return False;
}

def store_photo(photo_base64: str, mime_type: str) -> tuple[str, str] {
    if not photo_base64 {
        return ("", "");
    }
    safe_mime = mime_type.lower().strip();
    extensions = {
        "image/jpeg": "jpg", "image/jpg": "jpg", "image/png": "png",
        "image/webp": "webp", "image/heic": "heic"
    };
    if safe_mime not in extensions {
        raise ValueError("Daybook accepts JPEG, PNG, WebP, or HEIC photos");
    }
    encoded = photo_base64.split(",", 1)[-1];
    content = base64.b64decode(encoded, validate=True);
    if len(content) > 12 * 1024 * 1024 {
        raise ValueError("Photos must be 12 MB or smaller");
    }
    storage_path = f"photos/{uuid4()}.{extensions[safe_mime]}";
    PHOTO_STORE.upload(io.BytesIO(content), storage_path);
    return (storage_path, safe_mime);
}

def:pub create_moment(
    caption: str, kind: str = "ordinary", local_date: str = "",
    captured_at: str = "", thread_names: list[str] | None = None,
    photo_base64: str = "", photo_mime: str = ""
) -> MomentView {
    clean_caption = caption.strip();
    if not clean_caption and not photo_base64 {
        raise ValueError("A moment needs a photo or a few words");
    }
    day_key = resolved_date(local_date);
    timestamp = captured_at.strip() or now_iso();
    day = get_or_create_day(day_key);
    (photo_path, safe_mime) = store_photo(photo_base64, photo_mime);
    moment = day +>:Contains():+> Moment(
        caption=clean_caption, kind=validated_kind(kind),
        captured_at=timestamp, local_date=day_key,
        photo_path=photo_path, photo_mime=safe_mime
    );
    for thread_name in normalized_thread_names(thread_names or []) {
        moment +>:InThread():+> get_or_create_thread(thread_name);
    }
    return moment.to_view();
}

# Delete one moment owned by the current journal and its stored photo.
def:pub delete_moment(moment_id: str) -> bool {
    item = jobj(moment_id);
    if not isinstance(item, Moment) {
        return False;
    }
    owning_days = [item <-:Contains:<-];
    if not owning_days {
        return False;
    }
    day = owning_days[0];
    if not owns_day(day) {
        return False;
    }
    photo_path = item.photo_path;
    linked_threads = [item ->:InThread:->];
    del item;
    if not [day ->:Contains:->] and not [day ->:Plans:->] {
        del day;
    }
    if photo_path and PHOTO_STORE.exists(photo_path) {
        PHOTO_STORE.delete(photo_path);
    }
    for thread in linked_threads {
        if not [thread <-:InThread:<-] {
            del thread;
        }
    }
    return True;
}

# Return photo bytes only when the moment belongs to the caller's journal.
def:pub get_photo_data(photo_id: str) -> str {
    item = jobj(photo_id);
    if not isinstance(item, Moment) or not item.photo_path {
        return "";
    }
    owning_days = [item <-:Contains:<-];
    if not owning_days or not owns_day(owning_days[0]) or not PHOTO_STORE.exists(item.photo_path) {
        return "";
    }
    content = PHOTO_STORE.download(item.photo_path);
    encoded = base64.b64encode(content).decode("ascii");
    return f"data:{item.photo_mime};base64,{encoded}";
}

def:pub set_intention(text: str, target_date: str = "") -> IntentionView {
    clean_text = " ".join(text.strip().split());
    if not clean_text {
        raise ValueError("An intention needs a few words");
    }
    day_key = resolved_date(target_date);
    day = get_or_create_day(day_key);
    intentions = [day ->:Plans:->];
    if intentions {
        intention = intentions[0];
        intention.text = clean_text;
        intention.completed = False;
    } else {
        intention = day +>:Plans():+> Intention(
            text=clean_text, target_date=day_key
        );
    }
    return intention.to_view();
}

def:pub toggle_intention(intention_id: str) -> IntentionView {
    item = jobj(intention_id);
    if not isinstance(item, Intention) {
        return IntentionView();
    }
    owning_days = [item <-:Plans:<-];
    if not owning_days or not owns_day(owning_days[0]) {
        return IntentionView();
    }
    item.completed = not item.completed;
    return item.to_view();
}

def:pub delete_intention(intention_id: str) -> bool {
    item = jobj(intention_id);
    if not isinstance(item, Intention) {
        return False;
    }
    owning_days = [item <-:Plans:<-];
    if not owning_days or not owns_day(owning_days[0]) {
        return False;
    }
    day = owning_days[0];
    del item;
    if not [day ->:Contains:->] {
        del day;
    }
    return True;
}

def:pub get_day(local_date: str = "") -> DayView {
    day_key = resolved_date(local_date);
    matches = [root-->[?:Day, date == day_key]];
    if matches {
        return matches[0].to_view();
    }
    return DayView(date=day_key, prompt=prompt_for_date(day_key));
}

def calendar_for_month(month: str) -> tuple[str, str, list[CalendarCell]] {
    chosen = month.strip() or today_key()[:7];
    try {
        first = datetime.date.fromisoformat(chosen + "-01");
    } except Exception {
        first = datetime.date.today().replace(day=1);
        chosen = first.strftime("%Y-%m");
    }
    cells: list[CalendarCell] = [];
    weeks = calendar.Calendar(firstweekday=0).monthdayscalendar(
        first.year, first.month
    );
    for week in weeks {
        for day_number in week {
            if day_number == 0 {
                cells.append(CalendarCell());
            } else {
                day_key = f"{first.year:04d}-{first.month:02d}-{day_number:02d}";
                matches = [root-->[?:Day, date == day_key]];
                day_view = matches[0].to_view() if matches else DayView(date=day_key);
                cells.append(CalendarCell(
                    date=day_key, day_number=day_number, in_month=True,
                    moment_count=day_view.moment_count,
                    cover_photo_url=day_view.cover_photo_url,
                    has_intention=bool(day_view.intention.id),
                    intention_completed=day_view.intention.completed
                ));
            }
        }
    }
    return (chosen, first.strftime("%B %Y"), cells);
}

def:pub get_snapshot(month: str = "") -> JournalSnapshot {
    day_views = [day.to_view() for day in [root-->[?:Day]]];
    day_views.sort(key=lambda (item: DayView) { item.date; }, reverse=True);
    thread_views = [thread.to_view() for thread in [root-->[?:Thread]]];
    thread_views.sort(
        key=lambda (item: ThreadView) { item.moment_count; }, reverse=True
    );
    (chosen, label, cells) = calendar_for_month(month);
    intentions = [day.intention for day in day_views if day.intention.id];
    return JournalSnapshot(
        month=chosen, month_label=label, today=today_key(),
        total_moments=sum([day.moment_count for day in day_views]),
        total_photos=sum([day.photo_count for day in day_views]),
        total_intentions=len(intentions),
        completed_intentions=len([item for item in intentions if item.completed]),
        days=day_views, threads=thread_views, calendar=cells
    );
}

def:pub shift_month(month: str, delta: int) -> str {
    shifted = shifted_month(month, delta);
    return today_key()[:7] if shifted == "1970-01" else shifted;
}

def:pub seed_demo -> JournalSnapshot {
    if [root-->[?:Moment]] {
        return get_snapshot();
    }
    today = datetime.date.today();
    demo = [
        (0, "Coffee and a long conversation before class", "coffee", ["Coffee chats"]),
        (0, "Finally untangled the bug I had been staring at", "work", ["Building", "Small wins"]),
        (1, "A very good bowl of noodles", "food", ["Things I ate"]),
        (2, "The light outside looked unreal for five minutes", "ordinary", ["Campus light"])
    ];
    for (days_ago, caption, kind, threads) in demo {
        day = today - datetime.timedelta(days=days_ago);
        create_moment(
            caption=caption, kind=kind, local_date=day.isoformat(),
            captured_at=f"{day.isoformat()}T18:00:00+00:00", thread_names=threads
        );
    }
    set_intention("Make room for one thing that matters", today.isoformat());
    return get_snapshot();
}

test "text moments link one day to deduplicated threads" {
    moment = create_moment(
        caption="A careful coffee chat", kind="coffee",
        local_date="2040-01-02",
        thread_names=["Coffee Chats", " coffee chats ", "Research"]
    );
    day = get_day("2040-01-02");
    snapshot = get_snapshot("2040-01");
    assert moment.thread_names == ["Coffee Chats", "Research"];
    assert day.moment_count == 1;
    assert day.photo_count == 0;
    assert snapshot.total_moments == 1;
    assert len(snapshot.threads) == 2;
    assert delete_moment(moment.id);
}

test "photo data loads and deleting a moment removes its day" {
    tiny_png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=";
    moment = create_moment(
        caption="Temporary photo", kind="ordinary", local_date="2040-02-03",
        photo_base64=tiny_png, photo_mime="image/png"
    );
    assert get_photo_data(moment.id).startswith("data:image/png;base64,");
    assert delete_moment(moment.id);
    assert get_day("2040-02-03").moment_count == 0;
    assert get_photo_data(moment.id) == "";
}

test "deleting the last moment also removes its unused threads" {
    moment = create_moment(
        caption="Temporary thread", local_date="2040-02-04",
        thread_names=["Temporary deletion test"]
    );
    assert len([root-->[?:Thread, normalized_name == "temporary deletion test"]]) == 1;
    assert delete_moment(moment.id);
    assert len([root-->[?:Thread, normalized_name == "temporary deletion test"]]) == 0;
}

test "daily intentions can be planned completed and removed" {
    intention = set_intention("Finish the project review", "2040-03-04");
    assert intention.text == "Finish the project review";
    assert not intention.completed;
    assert get_day("2040-03-04").intention.id == intention.id;
    completed = toggle_intention(intention.id);
    assert completed.completed;
    assert delete_intention(intention.id);
    assert get_day("2040-03-04").intention.id == "";
}
