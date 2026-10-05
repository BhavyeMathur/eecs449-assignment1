"""Client behavior for the Daybook web application."""

impl DaybookApp.load(month: str) -> None {
    busy = True;
    error = "";
    try {
        endpoint = get_snapshot;
        snapshot = await endpoint(month);
        await loadPhotoSources();
        if not selected_date {
            selected_date = snapshot.today;
        }
    } except Exception as exc {
        error = "Could not reach your Daybook: " + str(exc);
    }
    busy = False;
}

impl DaybookApp.loadPhotoSources -> None {
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

impl DaybookApp.changeMonth(delta: int) -> None {
    endpoint = shift_month;
    next_month = await endpoint(snapshot.month, delta);
    selected_date = next_month + "-01";
    await load(next_month);
}

impl DaybookApp.selectDay(date_key: str) -> None {
    if date_key {
        selected_date = date_key;
        intention_text = "";
    }
}

impl DaybookApp.selectThread(thread_id: str) -> None {
    selected_thread_id = thread_id;
}

impl DaybookApp.selectMoment(moment_id: str) -> None {
    selected_moment_id = moment_id;
    delete_confirming = False;
    error = "";
}

impl DaybookApp.closeMoment -> None {
    if not busy {
        selected_moment_id = "";
        delete_confirming = False;
    }
}

impl DaybookApp.setDeleteConfirmation(confirming: bool) -> None {
    delete_confirming = confirming;
}

impl DaybookApp.deleteSelectedMoment -> None {
    if not selected_moment_id {
        return;
    }
    busy = True;
    error = "";
    try {
        endpoint = delete_moment;
        removed = await endpoint(selected_moment_id);
        if not removed {
            error = "That moment could not be found.";
        } else {
            selected_moment_id = "";
            delete_confirming = False;
            notice = "Moment deleted.";
            selected_date = "";
            await load(snapshot.month);
        }
    } except Exception as exc {
        error = "That moment could not be deleted: " + str(exc);
    }
    busy = False;
}

impl DaybookApp.updateIntentionText(text: str) -> None {
    intention_text = text;
}

impl DaybookApp.saveIntention(e: FormEvent) -> None {
    e.preventDefault();
    clean_text = intention_text.strip();
    if not clean_text {
        return;
    }
    busy = True;
    error = "";
    notice = "";
    try {
        endpoint = set_intention;
        await endpoint(clean_text, selected_date);
        intention_text = "";
        notice = "Intention set for this day.";
        await load(snapshot.month);
    } except Exception as exc {
        error = "That intention could not be saved: " + str(exc);
    }
    busy = False;
}

impl DaybookApp.toggleIntention(intention_id: str) -> None {
    busy = True;
    error = "";
    try {
        endpoint = toggle_intention;
        updated = await endpoint(intention_id);
        if not updated.id {
            error = "That intention could not be found.";
        } else {
            notice = "Intention completed." if updated.completed else "Intention reopened.";
            await load(snapshot.month);
        }
    } except Exception as exc {
        error = "That intention could not be updated: " + str(exc);
    }
    busy = False;
}

impl DaybookApp.removeIntention(intention_id: str) -> None {
    busy = True;
    error = "";
    try {
        endpoint = delete_intention;
        removed = await endpoint(intention_id);
        if not removed {
            error = "That intention could not be found.";
        } else {
            notice = "Intention removed.";
            await load(snapshot.month);
        }
    } except Exception as exc {
        error = "That intention could not be removed: " + str(exc);
    }
    busy = False;
}

impl DaybookApp.openComposer -> None {
    error = "";
    notice = "";
    composer_open = True;
}

impl DaybookApp.closeComposer -> None {
    if not busy {
        composer_open = False;
    }
}

impl DaybookApp.clearComposer -> None {
    caption = "";
    kind = "ordinary";
    selected_thread_names = [];
    new_thread_name = "";
    new_thread_open = False;
    photo_data = [];
    photo_mimes = [];
    photo_names = [];
}

impl DaybookApp.readFiles(files: any) -> None {
    if not files {
        return;
    }
    remaining = 6 - len(photo_data);
    if remaining <= 0 {
        error = "You can add up to six photos at a time.";
        return;
    }
    error = "";
    limit = min(len(files), remaining);
    for index in range(limit) {
        readOneFile(files[index]);
    }
}

impl DaybookApp.readOneFile(file: any) -> None {
    mime = str(file.type or "").lower();
    if mime not in ["image/jpeg", "image/jpg", "image/png", "image/webp", "image/heic"] {
        error = "Daybook accepts JPEG, PNG, WebP, or HEIC photos.";
        return;
    }
    if int(file.size or 0) > 12 * 1024 * 1024 {
        error = "Each photo must be 12 MB or smaller.";
        return;
    }
    reader: any = globalThis.Reflect.construct(globalThis.FileReader, []);
    reader.onload = lambda (_event: Event) {
        photo_data = photo_data + [str(reader.result)];
        photo_mimes = photo_mimes + [mime];
        photo_names = photo_names + [str(file.name or "Selected photo")];
    };
    reader.onerror = lambda (_event: Event) {
        error = "One of those photos could not be read.";
    };
    reader.readAsDataURL(file);
}

impl DaybookApp.handleFiles(e: ChangeEvent) -> None {
    files: any = e.target.files;
    readFiles(files);
    e.target.value = "";
}

impl DaybookApp.handleDrop(e: Event) -> None {
    e.preventDefault();
    drag_event: any = e;
    readFiles(drag_event.dataTransfer.files);
}

impl DaybookApp.allowDrop(e: Event) -> None {
    e.preventDefault();
}

impl DaybookApp.removePhoto(index: int) -> None {
    photo_data = [photo for (item_index, photo) in enumerate(photo_data) if item_index != index];
    photo_mimes = [mime for (item_index, mime) in enumerate(photo_mimes) if item_index != index];
    photo_names = [name for (item_index, name) in enumerate(photo_names) if item_index != index];
}

impl DaybookApp.toggleComposerThread(name: str) -> None {
    if name in selected_thread_names {
        selected_thread_names = [item for item in selected_thread_names if item != name];
    } else {
        selected_thread_names = selected_thread_names + [name];
    }
}

impl DaybookApp.addComposerThread -> None {
    clean_name = " ".join(new_thread_name.strip().split());
    if not clean_name {
        return;
    }
    existing_name = "";
    for thread in snapshot.threads {
        if thread.name.lower() == clean_name.lower() {
            existing_name = thread.name;
        }
    }
    chosen_name = existing_name or clean_name;
    if chosen_name not in selected_thread_names {
        selected_thread_names = selected_thread_names + [chosen_name];
    }
    new_thread_name = "";
    new_thread_open = False;
}

impl DaybookApp.addMoment(e: FormEvent) -> None {
    e.preventDefault();
    clean_caption = caption.strip();
    if not clean_caption and not photo_data {
        error = "Add a photo or a few words first.";
        return;
    }
    busy = True;
    error = "";
    notice = "";
    try {
        names = selected_thread_names;
        endpoint = create_moment;
        if photo_data {
            for (index, photo) in enumerate(photo_data) {
                await endpoint(clean_caption if index == 0 else "", kind, "", "", names, photo, photo_mimes[index]);
            }
            saved_count = len(photo_data);
            saved_noun = "photo" if saved_count == 1 else "photos";
            notice = f"Kept {saved_count} {saved_noun}.";
        } else {
            await endpoint(clean_caption, kind, "", "", names, "", "");
            notice = "Moment kept.";
        }
        clearComposer();
        composer_open = False;
        selected_date = "";
        await load(snapshot.month);
    } except Exception as exc {
        error = "That moment could not be saved: " + str(exc);
    }
    busy = False;
}

impl DaybookApp.addDemo -> None {
    busy = True;
    error = "";
    try {
        endpoint = seed_demo;
        snapshot = await endpoint();
        await loadPhotoSources();
        selected_date = snapshot.today;
    } except Exception as exc {
        error = "The demo could not be loaded: " + str(exc);
    }
    busy = False;
}
