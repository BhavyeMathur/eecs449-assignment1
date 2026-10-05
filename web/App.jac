"""Photo-first timeline, calendar, threads, and capture for Daybook web."""

import from core.journal {
    MomentView, IntentionView, DayView, ThreadView, CalendarCell,
    JournalSnapshot, create_moment, delete_intention, delete_moment,
    get_photo_data, get_snapshot, set_intention, shift_month, seed_demo,
    toggle_intention
}

glob KINDS: list[str] = [
    "ordinary", "food", "work", "coffee", "event", "campus", "people"
], MONTHS: list[str] = [
    "", "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
];

def kind_label(kind: str) -> str {
    labels = {
        "ordinary": "Ordinary", "food": "Food", "work": "Work",
        "coffee": "Coffee chat", "event": "Event", "campus": "Out there",
        "people": "People"
    };
    return str(labels.get(kind, "Ordinary"));
}

def kind_symbol(kind: str) -> str {
    symbols = {
        "ordinary": "✦", "food": "◒", "work": "⌁", "coffee": "☕",
        "event": "◇", "campus": "⌂", "people": "◎"
    };
    return str(symbols.get(kind, "✦"));
}

def date_label(date_key: str) -> str {
    parts = date_key.split("-");
    if len(parts) != 3 {
        return date_key;
    }
    month_number = int(parts[1]);
    month_name = MONTHS[month_number] if month_number > 0 and month_number < len(MONTHS) else parts[1];
    return f"{month_name} {int(parts[2])}, {parts[0]}";
}

def short_date_label(date_key: str, today: str) -> str {
    if date_key == today {
        return "Today";
    }
    parts = date_key.split("-");
    if len(parts) != 3 {
        return date_key;
    }
    month_number = int(parts[1]);
    month_name = MONTHS[month_number][:3] if month_number > 0 and month_number < len(MONTHS) else parts[1];
    return f"{month_name} {int(parts[2])}";
}

def time_label(timestamp: str) -> str {
    return timestamp[11:16] if len(timestamp) >= 16 else "";
}

# Resolve a lightweight photo reference from the app's in-memory photo cache.
def photo_source(photo_sources: dict[str, str], url: str) -> str {
    if not url {
        return "";
    }
    photo_id = url.rsplit("/", 1)[-1];
    return str(photo_sources.get(photo_id, ""));
}

def day_from_snapshot(snapshot: JournalSnapshot, date_key: str) -> DayView {
    for day in snapshot.days {
        if day.date == date_key {
            return day;
        }
    }
    return DayView(date=date_key, intention=IntentionView());
}

def thread_from_snapshot(threads: list[ThreadView], thread_id: str) -> ThreadView {
    for thread in threads {
        if thread.id == thread_id {
            return thread;
        }
    }
    return ThreadView();
}

def moment_from_snapshot(snapshot: JournalSnapshot, moment_id: str) -> MomentView {
    for day in snapshot.days {
        for moment in day.moments {
            if moment.id == moment_id {
                return moment;
            }
        }
    }
    return MomentView();
}

def threads_for_day(day: DayView, threads: list[ThreadView]) -> list[ThreadView] {
    names: list[str] = [];
    for moment in day.moments {
        for name in moment.thread_names {
            if name not in names {
                names.append(name);
            }
        }
    }
    return [thread for thread in threads if thread.name in names];
}

def moment_class(index: int, moment: MomentView) -> str {
    base = "story-photo story-photo-main" if index == 0 else "story-photo story-photo-small";
    return base + ("" if moment.photo_url else f" story-photo-text kind-{moment.kind}");
}

def MomentTile(moment: MomentView, index: int, photo_sources: dict[str, str], on_select: Callable[[str], None]) -> JsxElement {
    <button type="button" className={moment_class(index, moment)} onClick={lambda { on_select(moment.id); }} aria-label={"Open moment: " + (moment.caption or kind_label(moment.kind))}>
        {<img src={photo_source(photo_sources, moment.photo_url)} alt={moment.caption or kind_label(moment.kind)}/> if photo_source(photo_sources, moment.photo_url) else (
            <div className="story-photo-placeholder" aria-hidden="true"><span>{kind_symbol(moment.kind)}</span></div>
        )}
        <div className="story-photo-caption">
            <span className="story-photo-meta">{time_label(moment.captured_at)} {" · "}{kind_label(moment.kind)}</span>
            <strong>{moment.caption or "A moment worth keeping"}</strong>
            {<span className="story-photo-thread">↳ {moment.thread_names[0]}</span> if len(moment.thread_names) > 0 else <></>}
        </div>
        <span className="open-moment-cue" aria-hidden="true">↗</span>
    </button>
}

def DayRail(snapshot: JournalSnapshot, selected_date: str, photo_sources: dict[str, str], on_select: Callable[[str], None]) -> JsxElement {
    <aside className="days-rail" aria-label="Recent days">
        <p className="section-kicker">Recent days</p>
        <div className="day-links">
            {[
                <button className={"day-link selected" if day.date == selected_date else "day-link"}
                    type="button" key={day.date} onClick={lambda { on_select(day.date); }}>
                    <span className={"day-thumb kind-" + (day.moments[0].kind if len(day.moments) > 0 else "ordinary")}>
                        {<img src={photo_source(photo_sources, day.cover_photo_url)} alt=""/> if photo_source(photo_sources, day.cover_photo_url) else <span>{kind_symbol(day.moments[0].kind) if len(day.moments) > 0 else "✦"}</span>}
                    </span>
                    <span className="day-link-copy"><strong>{short_date_label(day.date, snapshot.today)}</strong><small>{day.moment_count} {"moment" if day.moment_count == 1 else "moments"}</small></span>
                </button>
                for day in snapshot.days[:7]
            ]}
        </div>
    </aside>
}

def TodayView(snapshot: JournalSnapshot, selected_date: str, photo_sources: dict[str, str], on_select_day: Callable[[str], None], on_select_moment: Callable[[str], None], on_add: Callable[[], None], on_demo: Callable[[], None]) -> JsxElement {
    chosen = day_from_snapshot(snapshot, selected_date);
    active_threads = threads_for_day(chosen, snapshot.threads);

    <section className="today-layout">
        <DayRail snapshot={snapshot} selected_date={selected_date} photo_sources={photo_sources} on_select={on_select_day}/>
        <article className="day-story" aria-label="Daily photo story">
            <header className="day-story-header">
                <p className="section-kicker">{date_label(chosen.date) if chosen.date else "Today"}</p>
                <h1>{"Today, as it happened." if chosen.date == snapshot.today else "A day, as it happened."}</h1>
                <p>{chosen.moment_count} {"small piece" if chosen.moment_count == 1 else "small pieces"} of a day worth remembering.</p>
            </header>
            {(
                <>
                    <div className="story-grid">{[<MomentTile key={moment.id} moment={moment} index={index} photo_sources={photo_sources} on_select={on_select_moment}/> for (index, moment) in enumerate(chosen.moments)]}</div>
                    <footer className="day-story-footer"><p>“{chosen.prompt}”</p></footer>
                </>
            ) if len(chosen.moments) > 0 else (
                <section className="day-empty">
                    <span>✦</span><h2>This day is still open.</h2><p>One photo is enough to begin remembering it.</p>
                    <div className="empty-actions">
                        <button className="primary-action" type="button" onClick={on_add}>Add a moment</button>
                        {<button className="quiet-action" type="button" onClick={on_demo}>Load demo moments</button> if len(snapshot.days) == 0 else <></>}
                    </div>
                </section>
            )}
        </article>
        <aside className="today-context" aria-label="Today details">
            <section className="prompt-panel">
                <span className="prompt-symbol">✦</span><h2>One more thing from today?</h2>
                <p>A photo is enough. Add words only if they matter.</p><button type="button" onClick={on_add}>Add a moment →</button>
            </section>
            {(
                <section className="today-threads"><h2>Threads in this day</h2>{[
                    <div className="mini-thread" key={thread.id}><span className="thread-swatch" style={{"backgroundColor": thread.color}}></span><span><strong>{thread.name}</strong><small>{thread.moment_count} moments</small></span></div>
                    for thread in active_threads[:4]
                ]}</section>
            ) if len(active_threads) > 0 else <></>}
        </aside>
    </section>
}

def PlanningStrip(day: DayView, draft: str, busy: bool, on_change: Callable[[str], None], on_save: Callable[[FormEvent], None], on_toggle: Callable[[str], None], on_delete: Callable[[str], None]) -> JsxElement {
    intention = day.intention;
    <section className="planning-strip" aria-label="Daily intention">
        <div className="planning-label"><span>◎</span><div><p className="section-kicker">Daily intention</p><small>{date_label(day.date)}</small></div></div>
        {(
            <div className="intention-current">
                <button className={"intention-check" + (" complete" if intention.completed else "")} type="button" aria-label={"Mark intention not done" if intention.completed else "Mark intention done"} onClick={lambda { on_toggle(intention.id); }}>{"✓" if intention.completed else ""}</button>
                <strong className={"done" if intention.completed else ""}>{intention.text}</strong>
                <div className="intention-actions"><button type="button" onClick={lambda { on_toggle(intention.id); }}>{"Undo" if intention.completed else "Done"}</button><button type="button" onClick={lambda { on_delete(intention.id); }}>Remove</button></div>
            </div>
        ) if intention.id else (
            <form className="intention-form" onSubmit={on_save}><label htmlFor="intention-input">What do you want to make room for?</label><input id="intention-input" value={draft} onChange={lambda (e: ChangeEvent) { on_change(e.target.value); }} placeholder="One meaningful thing for this day"/><button type="submit" disabled={busy or not draft.strip()}>Set intention</button></form>
        )}
    </section>
}

def CalendarView(snapshot: JournalSnapshot, selected_date: str, photo_sources: dict[str, str], on_select_day: Callable[[str], None], on_shift: Callable[[int], None]) -> JsxElement {
    chosen = day_from_snapshot(snapshot, selected_date);
    <section className="archive-page">
        <header className="archive-heading">
            <div><p className="section-kicker">Your days at a glance</p><h1>{snapshot.month_label}</h1></div>
            <div className="month-controls" aria-label="Change month"><button type="button" aria-label="Previous month" onClick={lambda { on_shift(-1); }}>←</button><button type="button" aria-label="Next month" onClick={lambda { on_shift(1); }}>→</button></div>
        </header>
        <div className="calendar-layout">
            <div className="calendar-shell">
                <div className="weekday-row">{[<span key={name}>{name}</span> for name in ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]]}</div>
                <div className="calendar-grid">{[
                    <button key={index} type="button" disabled={not cell.in_month}
                        className={"calendar-cell" + (" has-moments" if cell.moment_count else "") + (" has-intention" if cell.has_intention else "") + (" selected" if cell.date == selected_date else "")}
                        onClick={lambda { on_select_day(cell.date); }}>
                        {(
                            <>{<img src={photo_source(photo_sources, cell.cover_photo_url)} alt=""/> if photo_source(photo_sources, cell.cover_photo_url) else <span className="calendar-wash">{"✦" if cell.moment_count else ""}</span>}<strong>{cell.day_number}</strong>{<small>{cell.moment_count}</small> if cell.moment_count else <></>}{<span className={"calendar-intention" + (" complete" if cell.intention_completed else "")} aria-label="Intention"></span> if cell.has_intention else <></>}</>
                        ) if cell.in_month else <></>}
                    </button>
                    for (index, cell) in enumerate(snapshot.calendar)
                ]}</div>
            </div>
            <aside className="calendar-detail" aria-live="polite">
                <p className="section-kicker">Selected day</p><h2>{date_label(selected_date) if selected_date else "Choose a day"}</h2>
                {(
                    <><div className={"calendar-detail-photo kind-" + (chosen.moments[0].kind if len(chosen.moments) > 0 else "ordinary")}>{<img src={photo_source(photo_sources, chosen.cover_photo_url)} alt=""/> if photo_source(photo_sources, chosen.cover_photo_url) else <span>{kind_symbol(chosen.moments[0].kind) if len(chosen.moments) > 0 else "✦"}</span>}</div><p>{chosen.moment_count} {"moment" if chosen.moment_count == 1 else "moments"} · {chosen.prompt}</p></>
                ) if len(chosen.moments) > 0 else <p className="calendar-detail-empty">No moments here yet.</p>}
                {<div className={"calendar-plan" + (" complete" if chosen.intention.completed else "")}><span>{"✓" if chosen.intention.completed else "◎"}</span><p><small>Intention</small>{chosen.intention.text}</p></div> if chosen.intention.id else <></>}
            </aside>
        </div>
    </section>
}

def ThreadCollage(thread: ThreadView, photo_sources: dict[str, str]) -> JsxElement {
    photos = [moment for moment in thread.moments if moment.photo_url];
    <div className="thread-collage" style={{"backgroundColor": thread.color}}>
        <div className="thread-collage-main">{<img src={photo_source(photo_sources, photos[0].photo_url)} alt=""/> if len(photos) > 0 and photo_source(photo_sources, photos[0].photo_url) else <span>#{thread.name[:1]}</span>}</div>
        <div className="thread-collage-side"><div>{<img src={photo_source(photo_sources, photos[1].photo_url)} alt=""/> if len(photos) > 1 and photo_source(photo_sources, photos[1].photo_url) else <span>✦</span>}</div><div>{<img src={photo_source(photo_sources, photos[2].photo_url)} alt=""/> if len(photos) > 2 and photo_source(photo_sources, photos[2].photo_url) else <span>·</span>}</div></div>
    </div>
}

def ThreadsView(threads: list[ThreadView], selected_thread_id: str, photo_sources: dict[str, str], on_select: Callable[[str], None], on_select_moment: Callable[[str], None]) -> JsxElement {
    selected = thread_from_snapshot(threads, selected_thread_id);
    <section className="archive-page threads-page">
        <header className="archive-heading"><div><p className="section-kicker">Stories that keep returning</p><h1>Threads</h1></div></header>
        {(
            <section className="selected-thread-story"><div className="selected-thread-heading"><div><p className="section-kicker">Open thread</p><h2>{selected.name}</h2></div><button type="button" aria-label="Close thread" onClick={lambda { on_select(""); }}>×</button></div><div className="selected-thread-grid">{[<MomentTile key={moment.id} moment={moment} index={index} photo_sources={photo_sources} on_select={on_select_moment}/> for (index, moment) in enumerate(selected.moments)]}</div></section>
        ) if selected.id else <></>}
        {(
            <div className="thread-gallery">{[
                <button className="thread-card" type="button" key={thread.id} onClick={lambda { on_select(thread.id); }}><ThreadCollage thread={thread} photo_sources={photo_sources}/><span className="thread-info"><span><strong>{thread.name}</strong><small>{thread.moment_count} moments across your days</small></span><span className="thread-arrow">→</span></span></button>
                for thread in threads
            ]}</div>
        ) if len(threads) > 0 else <section className="day-empty compact-empty"><span>≈</span><h2>Your threads will meet here.</h2><p>Add a thread name when you keep a moment.</p></section>}
    </section>
}

def MomentViewer(moment: MomentView, photo_sources: dict[str, str], confirming: bool, busy: bool, on_close: Callable[[], None], on_confirmation: Callable[[bool], None], on_delete: Callable[[], None]) -> JsxElement {
    <div className="moment-viewer-layer" role="presentation">
        <button className="viewer-scrim" type="button" aria-label="Close moment" onClick={on_close}></button>
        <article className="moment-viewer" role="dialog" aria-modal="true" aria-label="Moment details">
            <button className="viewer-close" type="button" aria-label="Close moment" onClick={on_close}>×</button>
            <div className={"viewer-photo kind-" + moment.kind}>
                {<img src={photo_source(photo_sources, moment.photo_url)} alt={moment.caption or kind_label(moment.kind)}/> if photo_source(photo_sources, moment.photo_url) else <span>{kind_symbol(moment.kind)}</span>}
            </div>
            <div className="viewer-copy">
                <p className="section-kicker">{date_label(moment.local_date)} · {time_label(moment.captured_at)}</p>
                <h2>{moment.caption or "A moment worth keeping"}</h2>
                <div className="viewer-meta"><span>{kind_label(moment.kind)}</span>{[<span key={name}>#{name}</span> for name in moment.thread_names]}</div>
                {(
                    <div className="delete-confirm" role="alert"><p>Delete this moment permanently?</p><div><button type="button" onClick={lambda { on_confirmation(False); }}>Keep it</button><button className="delete-final" type="button" disabled={busy} onClick={on_delete}>{"Deleting…" if busy else "Yes, delete"}</button></div></div>
                ) if confirming else <button className="delete-moment" type="button" onClick={lambda { on_confirmation(True); }}>Delete moment</button>}
            </div>
        </article>
    </div>
}

def:pub DaybookApp -> JsxElement {
    has snapshot: JournalSnapshot = JournalSnapshot(), view: str = "today",
        selected_date: str = "", selected_thread_id: str = "",
        selected_moment_id: str = "", delete_confirming: bool = False,
        photo_sources: dict[str, str] = {},
        intention_text: str = "",
        composer_open: bool = False, caption: str = "", kind: str = "ordinary",
        selected_thread_names: list[str] = [], new_thread_name: str = "",
        new_thread_open: bool = False, busy: bool = False, error: str = "",
        notice: str = "", photo_data: list[str] = [],
        photo_mimes: list[str] = [], photo_names: list[str] = [];

    can with entry { load(""); }

    async def load(month: str) -> None;
    async def loadPhotoSources -> None;
    async def changeMonth(delta: int) -> None;
    def selectDay(date_key: str) -> None;
    def selectThread(thread_id: str) -> None;
    def selectMoment(moment_id: str) -> None;
    def closeMoment -> None;
    def setDeleteConfirmation(confirming: bool) -> None;
    async def deleteSelectedMoment -> None;
    def updateIntentionText(text: str) -> None;
    async def saveIntention(e: FormEvent) -> None;
    async def toggleIntention(intention_id: str) -> None;
    async def removeIntention(intention_id: str) -> None;
    def openComposer -> None;
    def closeComposer -> None;
    def clearComposer -> None;
    def readFiles(files: any) -> None;
    def readOneFile(file: any) -> None;
    def handleFiles(e: ChangeEvent) -> None;
    def handleDrop(e: Event) -> None;
    def allowDrop(e: Event) -> None;
    def removePhoto(index: int) -> None;
    def toggleComposerThread(name: str) -> None;
    def addComposerThread -> None;
    async def addMoment(e: FormEvent) -> None;
    async def addDemo -> None;

    <div className={"daybook-app" + (" composer-open" if composer_open else "")}>
        <header className="app-topbar">
            <button className="wordmark" type="button" onClick={lambda { view = "today"; }} aria-label="Daybook home"><span className="wordmark-mark"></span><span>Daybook</span></button>
            <nav className="app-tabs" aria-label="Primary navigation">
                <button type="button" className={"active" if view == "today" else ""} onClick={lambda { view = "today"; }}>Today</button>
                <button type="button" className={"active" if view == "calendar" else ""} onClick={lambda { view = "calendar"; }}>Calendar</button>
                <button type="button" className={"active" if view == "threads" else ""} onClick={lambda { view = "threads"; }}>Threads</button>
            </nav>
            <div className="topbar-actions"><span>A small record of ordinary days</span><button className="add-moment-button" type="button" onClick={openComposer}><span className="add-symbol">+</span> Add moment</button></div>
        </header>

        {<p className="error-banner" role="alert">{error}</p> if error and not composer_open else <></>}
        {<p className="notice-banner" role="status">{notice}</p> if notice and not composer_open else <></>}

        {<PlanningStrip day={day_from_snapshot(snapshot, selected_date)} draft={intention_text} busy={busy} on_change={updateIntentionText} on_save={saveIntention} on_toggle={toggleIntention} on_delete={removeIntention}/> if view == "today" and selected_date else <></>}

        <main>
            {<TodayView snapshot={snapshot} selected_date={selected_date} photo_sources={photo_sources} on_select_day={selectDay} on_select_moment={selectMoment} on_add={openComposer} on_demo={addDemo}/> if view == "today" else <></>}
            {<CalendarView snapshot={snapshot} selected_date={selected_date} photo_sources={photo_sources} on_select_day={selectDay} on_shift={changeMonth}/> if view == "calendar" else <></>}
            {<ThreadsView threads={snapshot.threads} selected_thread_id={selected_thread_id} photo_sources={photo_sources} on_select={selectThread} on_select_moment={selectMoment}/> if view == "threads" else <></>}
        </main>

        {<MomentViewer moment={moment_from_snapshot(snapshot, selected_moment_id)} photo_sources={photo_sources} confirming={delete_confirming} busy={busy} on_close={closeMoment} on_confirmation={setDeleteConfirmation} on_delete={deleteSelectedMoment}/> if selected_moment_id else <></>}

        <button className="composer-scrim" type="button" aria-label="Close add moment panel" onClick={closeComposer}></button>
        <aside className="moment-composer" aria-label="Add a moment" aria-hidden={not composer_open}>
            <div className="composer-heading"><div><p className="section-kicker">Today</p><h2>Add a moment</h2></div><button className="close-composer" type="button" aria-label="Close" onClick={closeComposer}>×</button></div>
            <form onSubmit={addMoment}>
                <label className="photo-dropzone" onDragOver={allowDrop} onDrop={handleDrop}>
                    <input type="file" accept="image/jpeg,image/png,image/webp,image/heic" multiple={True} onChange={handleFiles}/>
                    <span className="dropzone-symbol">＋</span><strong>{"Add more photos" if len(photo_data) > 0 else "Drop today’s photos here"}</strong><small>Drag them here, or choose up to six from your laptop.</small><span className="choose-photos">Choose photos</span>
                </label>
                {(
                    <div className="photo-previews" aria-label="Selected photos">{[
                        <figure key={index}><img src={photo} alt={photo_names[index]}/><button type="button" aria-label={"Remove " + photo_names[index]} onClick={lambda { removePhoto(index); }}>×</button></figure>
                        for (index, photo) in enumerate(photo_data)
                    ]}</div>
                ) if len(photo_data) > 0 else <></>}
                <label className="composer-field"><span>A few words, if you want</span><textarea value={caption} onChange={lambda (e: ChangeEvent) { caption = e.target.value; }} placeholder="What made this worth keeping?"></textarea></label>
                <fieldset className="kind-picker"><legend>Kind of moment</legend><div>{[
                    <button type="button" key={item} className={"active" if kind == item else ""} onClick={lambda { kind = item; }}>{kind_label(item)}</button>
                    for item in KINDS
                ]}</div></fieldset>
                <fieldset className="thread-picker"><legend>Threads</legend><p>Choose an existing thread so its name stays consistent.</p>
                    {<div className="chosen-threads">{[<button type="button" key={name} onClick={lambda { toggleComposerThread(name); }}>{name}<span>×</span></button> for name in selected_thread_names]}</div> if selected_thread_names else <></>}
                    <div className="thread-options">{[
                        <button type="button" key={thread.id} className={"active" if thread.name in selected_thread_names else ""} onClick={lambda { toggleComposerThread(thread.name); }}><span className="thread-option-dot" style={{"backgroundColor": thread.color}}></span>{thread.name}<span className="thread-option-check">{"✓" if thread.name in selected_thread_names else "+"}</span></button>
                        for thread in snapshot.threads
                    ]}</div>
                    {(
                        <div className="new-thread-row"><input value={new_thread_name} onChange={lambda (e: ChangeEvent) { new_thread_name = e.target.value; }} placeholder="Name this thread" aria-label="New thread name"/><button type="button" disabled={not new_thread_name.strip()} onClick={addComposerThread}>Add</button></div>
                    ) if new_thread_open else <button className="new-thread-toggle" type="button" onClick={lambda { new_thread_open = True; }}>＋ Create a new thread</button>}
                </fieldset>
                {<p className="composer-error" role="alert">{error}</p> if error else <></>}
                <button className="save-moment" type="submit" disabled={busy or (not caption.strip() and not photo_data)}>{"Keeping this moment…" if busy else (f"Keep {len(photo_data)} photos" if len(photo_data) > 1 else "Keep this moment")}</button>
            </form>
        </aside>
    </div>
}
