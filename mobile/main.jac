"""Daybook mobile app: quick photo capture, daily prompt, and recent days."""

import from "@jac/mobui" { Image, Pressable, ScrollView, Text, TextInput, View }
import from core.journal {
    DayView, IntentionView, JournalSnapshot, MomentView, create_moment, delete_intention,
    delete_moment, get_day, get_photo_data, get_snapshot, set_intention,
    toggle_intention
}
import from .device { choose_photo, ensure_daily_reminder }
import from .device_types { CapturedPhoto }
import from .theme { C, styles }
import from .components.Button { Button }

glob KINDS: list[str] = [
    "ordinary", "food", "work", "coffee", "event", "campus", "people"
];

def photo_source(photo_sources: dict[str, str], url: str) -> str {
    if not url {
        return "";
    }
    photo_id = url.rsplit("/", 1)[-1];
    return str(photo_sources.get(photo_id, ""));
}

def MomentRow(moment: MomentView, photo_sources: dict[str, str], confirming: bool, on_request_delete: Callable[[str], None], on_cancel_delete: Callable[[], None], on_delete: Callable[[str], None]) -> JsxElement {
    source = photo_source(photo_sources, moment.photo_url);
    <View style={styles.momentCard}>
        {(
            <Image source={{uri: source}} style={styles.momentImage}/>
        ) if source else <View style={styles.textMoment}><Text style={styles.textMomentGlyph}>✦</Text></View>}
        <View style={styles.momentBody}>
            <Text style={styles.momentKind}>{moment.kind.upper()}</Text>
            <Text style={styles.momentCaption}>{moment.caption or "An untitled moment"}</Text>
            {(
                <Text style={styles.momentThreads}>
                    {"  ".join([f"#{name}" for name in moment.thread_names])}
                </Text>
            ) if moment.thread_names else <Text></Text>}
            {(
                <View style={styles.deleteConfirm}><Text style={styles.deletePrompt}>Delete this moment?</Text><View style={styles.deleteActions}><Pressable onPress={on_cancel_delete}><Text style={styles.keepLabel}>Keep it</Text></Pressable><Pressable onPress={lambda { on_delete(moment.id); }}><Text style={styles.deleteLabel}>Yes, delete</Text></Pressable></View></View>
            ) if confirming else <Pressable style={styles.deleteLink} onPress={lambda { on_request_delete(moment.id); }}><Text style={styles.deleteLinkText}>Delete moment</Text></Pressable>}
        </View>
    </View>
}

def ThreadChoice(name: str, color: str, selected: bool, on_toggle: Callable[[str], None]) -> JsxElement {
    <Pressable style={[styles.threadChoice, styles.threadChoiceSelected if selected else {}]} onPress={lambda { on_toggle(name); }}>
        <View style={[styles.threadChoiceDot, {backgroundColor: color}]}/><Text style={styles.threadChoiceText}>{name}</Text><Text style={styles.threadChoiceMark}>{"✓" if selected else "+"}</Text>
    </Pressable>
}

def:pub app -> JsxElement {
    has today: DayView = DayView(intention=IntentionView()),
        snapshot: JournalSnapshot = JournalSnapshot(),
        photo: CapturedPhoto = CapturedPhoto(), caption: str = "",
        kind: str = "ordinary", selected_thread_names: list[str] = [],
        new_thread_name: str = "", photo_sources: dict[str, str] = {},
        intention_text: str = "", deleting_moment_id: str = "",
        busy: bool = False, notice: str = "", reminder_ready: bool = False;

    async can with entry {
        await refresh();
        intention_text = today.intention.text if today.intention else "";
        reminder_ready = await ensure_daily_reminder(20, 0);
    }

    async def refresh -> None {
        day_endpoint = get_day;
        snapshot_endpoint = get_snapshot;
        today = await day_endpoint("");
        snapshot = await snapshot_endpoint("");
        await loadPhotoSources();
    }

    async def loadPhotoSources -> None {
        next_sources: dict[str, str] = {};
        endpoint = get_photo_data;
        for day in snapshot.days {
            for moment in day.moments {
                if moment.photo_url and moment.id not in next_sources {
                    cached = str(photo_sources.get(moment.id, ""));
                    next_sources[moment.id] = cached or await endpoint(moment.id);
                }
            }
        }
        photo_sources = next_sources;
    }

    async def pick(source: str) -> None {
        notice = "";
        selected = await choose_photo(source);
        if not selected.cancelled {
            photo = selected;
        } else {
            notice = "Camera and photo library are available in the iOS/Android app.";
        }
    }

    async def save -> None {
        if not photo.base64_data and not caption.strip() {
            notice = "Add a photo or a short caption first.";
            return;
        }
        busy = True;
        notice = "";
        try {
            names = selected_thread_names;
            clean_new_thread = " ".join(new_thread_name.strip().split());
            duplicate = False;
            for name in names {
                if name.lower() == clean_new_thread.lower() {
                    duplicate = True;
                }
            }
            if clean_new_thread and not duplicate {
                names = names + [clean_new_thread];
            }
            endpoint = create_moment;
            await endpoint(
                caption, kind, "", "", names,
                photo.base64_data, photo.mime_type
            );
            photo = CapturedPhoto();
            caption = "";
            selected_thread_names = [];
            new_thread_name = "";
            notice = "Moment saved.";
            await refresh();
        } except Exception as exc {
            notice = "Could not save: " + str(exc);
        }
        busy = False;
    }

    def toggleThread(name: str) -> None {
        if name in selected_thread_names {
            selected_thread_names = [item for item in selected_thread_names if item != name];
        } else {
            selected_thread_names = selected_thread_names + [name];
        }
    }

    async def saveIntention -> None {
        clean_text = intention_text.strip();
        if not clean_text {
            notice = "Write one intention first.";
            return;
        }
        busy = True;
        notice = "";
        try {
            endpoint = set_intention;
            await endpoint(clean_text, "");
            notice = "Today's intention is set.";
            await refresh();
            intention_text = today.intention.text if today.intention else "";
        } except Exception as exc {
            notice = "Could not save intention: " + str(exc);
        }
        busy = False;
    }

    async def toggleTodayIntention -> None {
        active_intention = today.intention or IntentionView();
        if not active_intention.id {
            return;
        }
        busy = True;
        try {
            endpoint = toggle_intention;
            await endpoint(active_intention.id);
            await refresh();
            intention_text = today.intention.text if today.intention else "";
            notice = "Intention updated.";
        } except Exception as exc {
            notice = "Could not update intention: " + str(exc);
        }
        busy = False;
    }

    async def removeTodayIntention -> None {
        active_intention = today.intention or IntentionView();
        if not active_intention.id {
            return;
        }
        busy = True;
        try {
            endpoint = delete_intention;
            await endpoint(active_intention.id);
            intention_text = "";
            await refresh();
            notice = "Intention removed.";
        } except Exception as exc {
            notice = "Could not remove intention: " + str(exc);
        }
        busy = False;
    }

    def requestDelete(moment_id: str) -> None {
        deleting_moment_id = moment_id;
    }

    def cancelDelete -> None {
        deleting_moment_id = "";
    }

    async def removeMoment(moment_id: str) -> None {
        busy = True;
        try {
            endpoint = delete_moment;
            removed = await endpoint(moment_id);
            notice = "Moment deleted." if removed else "That moment could not be found.";
            deleting_moment_id = "";
            await refresh();
        } except Exception as exc {
            notice = "Could not delete moment: " + str(exc);
        }
        busy = False;
    }

    active_intention = today.intention or IntentionView();

    <ScrollView style={styles.screen} contentContainerStyle={styles.content}>
        <View style={styles.header}>
            <View>
                <Text style={styles.eyebrow}>DAYBOOK</Text>
                <Text style={styles.title}>Keep the texture.</Text>
            </View>
            <View style={styles.reminderPill}>
                <Text style={styles.reminderText}>{"8 PM reminder on" if reminder_ready else "Daily prompt"}</Text>
            </View>
        </View>

        <View style={styles.promptCard}>
            <Text style={styles.promptLabel}>TODAY'S PROMPT</Text>
            <Text style={styles.promptText}>{today.prompt}</Text>
            <Text style={styles.promptCount}>{today.photo_count} photos · {today.moment_count} moments today</Text>
        </View>

        <View style={styles.intentionCard}>
            <View style={styles.intentionHeading}><View><Text style={styles.promptLabel}>TODAY'S INTENTION</Text><Text style={styles.intentionHint}>One thing to make room for.</Text></View>{<Pressable style={[styles.intentionCheck, styles.intentionCheckDone if active_intention.completed else {}]} onPress={toggleTodayIntention}><Text style={styles.intentionCheckText}>{"✓" if active_intention.completed else ""}</Text></Pressable> if active_intention.id else <View/>}</View>
            <TextInput style={styles.intentionInput} value={intention_text} placeholder="What matters today?" placeholderTextColor={C.muted} onChangeText={lambda (text: str) { intention_text = text; }}/>
            <View style={styles.captureActions}><Button label={"Update intention" if active_intention.id else "Set intention"} onPress={saveIntention} disabled={busy or not intention_text.strip()}/>{<Button label="Remove" variant="secondary" onPress={removeTodayIntention} disabled={busy}/> if active_intention.id else <View/>}</View>
        </View>

        <View style={styles.captureCard}>
            {(
                <Image source={{uri: photo.uri}} style={styles.preview}/>
            ) if photo.uri else (
                <View style={styles.previewEmpty}>
                    <Text style={styles.previewGlyph}>◎</Text>
                    <Text style={styles.previewText}>Start with one photo.</Text>
                </View>
            )}
            <View style={styles.captureActions}>
                <Button label="Camera" onPress={lambda { pick("camera"); }}/>
                <Button label="Library" variant="secondary" onPress={lambda { pick("library"); }}/>
            </View>
            <TextInput
                style={styles.input} value={caption} placeholder="What is happening?"
                placeholderTextColor={C.muted}
                onChangeText={lambda (text: str) { caption = text; }} multiline={True}
            />
            <ScrollView horizontal={True} showsHorizontalScrollIndicator={False} contentContainerStyle={styles.kindRow}>
                {[
                    <Button key={item} label={item}
                        variant={"primary" if kind == item else "secondary"}
                        onPress={lambda { kind = item; }}/>
                    for item in KINDS
                ]}
            </ScrollView>
            <View style={styles.fieldGroup}><Text style={styles.fieldLabel}>THREADS</Text><Text style={styles.fieldHint}>Reuse a thread, or intentionally name a new one.</Text><View style={styles.threadChoices}>{[<ThreadChoice key={thread.id} name={thread.name} color={thread.color} selected={thread.name in selected_thread_names} on_toggle={toggleThread}/> for thread in snapshot.threads]}</View><TextInput style={styles.input} value={new_thread_name} placeholder="New thread (optional)" placeholderTextColor={C.muted} onChangeText={lambda (text: str) { new_thread_name = text; }}/></View>
            <Button label={"Saving…" if busy else "Save this moment"} onPress={save} disabled={busy}/>
            {<Text style={styles.notice}>{notice}</Text> if notice else <Text></Text>}
        </View>

        <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>Recent days</Text>
            <Text style={styles.sectionMeta}>{snapshot.total_moments} moments</Text>
        </View>
        {[
            <View key={day.date} style={styles.dayBlock}>
                <View style={styles.dayHeader}>
                    <Text style={styles.dayDate}>{day.date}</Text>
                    <Text style={styles.dayCount}>{day.moment_count}</Text>
                </View>
                {[<MomentRow key={moment.id} moment={moment} photo_sources={photo_sources} confirming={deleting_moment_id == moment.id} on_request_delete={requestDelete} on_cancel_delete={cancelDelete} on_delete={removeMoment}/> for moment in day.moments]}
            </View>
            for day in snapshot.days[:7]
        ]}

        <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>Threads</Text>
            <Text style={styles.sectionMeta}>Stories across days</Text>
        </View>
        <ScrollView horizontal={True} showsHorizontalScrollIndicator={False} contentContainerStyle={styles.threadRow}>
            {[
                <View key={thread.id} style={[styles.threadCard, {backgroundColor: thread.color}]}>
                    <Text style={styles.threadHash}>#</Text>
                    <Text style={styles.threadName}>{thread.name}</Text>
                    <Text style={styles.threadCount}>{thread.moment_count} moments</Text>
                </View>
                for thread in snapshot.threads
            ]}
        </ScrollView>
    </ScrollView>
}
