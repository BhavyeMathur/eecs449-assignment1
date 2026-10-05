"""Command-line capture and review for Daybook."""

import argparse;
import asyncio;
import sys;
import from core.journal {
    create_moment, delete_intention, get_day, get_snapshot, set_intention,
    toggle_intention
}

obj Invocation {
    has command: str = "", caption: str = "", kind: str = "ordinary",
        threads: list[str] = [], date: str = "";
}

def parser -> argparse.ArgumentParser {
    root_parser = argparse.ArgumentParser(
        prog="daybook", description="Capture and revisit everyday moments."
    );
    commands = root_parser.add_subparsers(dest="command", required=True);
    log = commands.add_parser("log", help="record a text or work moment");
    log.add_argument("caption", help="what happened");
    log.add_argument("--kind", `default="work", choices=[
        "ordinary", "food", "work", "coffee", "event", "campus", "people"
    ]);
    log.add_argument(
        "--thread", action="append", `default=[],
        help="reusable thread name; repeat to select more than one"
    );
    log.add_argument("--date", `default="", help="local date as YYYY-MM-DD");
    today = commands.add_parser("today", help="show today's moments");
    today.add_argument("--date", `default="", help="date as YYYY-MM-DD");
    plan = commands.add_parser("plan", help="set the intention for a day");
    plan.add_argument("caption", help="the one thing to make room for");
    plan.add_argument("--date", `default="", help="date as YYYY-MM-DD");
    done = commands.add_parser("done", help="toggle a day's intention complete");
    done.add_argument("--date", `default="", help="date as YYYY-MM-DD");
    clear_plan = commands.add_parser("clear-plan", help="remove a day's intention");
    clear_plan.add_argument("--date", `default="", help="date as YYYY-MM-DD");
    commands.add_parser("threads", help="show every active thread");
    return root_parser;
}

def parse_args(argv: list[str]) -> Invocation {
    args = parser().parse_args(argv);
    return Invocation(
        command=str(args.command or ""),
        caption=str(getattr(args, "caption", "") or ""),
        kind=str(getattr(args, "kind", "ordinary") or "ordinary"),
        threads=list(getattr(args, "thread", []) or []),
        date=str(getattr(args, "date", "") or "")
    );
}

async def dispatch(invocation: Invocation) -> int {
    if invocation.command == "log" {
        moment = await create_moment(
            caption=invocation.caption, kind=invocation.kind,
            local_date=invocation.date, captured_at="",
            thread_names=invocation.threads,
            photo_base64="", photo_mime=""
        );
        print(f"Saved {moment.kind} moment for {moment.local_date}: {moment.caption}");
        return 0;
    }
    if invocation.command == "today" {
        day = await get_day(local_date=invocation.date);
        print(f"\n{day.date} — {day.prompt}");
        print(f"{day.moment_count} moments · {day.photo_count} photos\n");
        if day.intention.id {
            marker = "✓" if day.intention.completed else "○";
            print(f"  {marker} intention  {day.intention.text}\n");
        }
        for moment in day.moments {
            tags = " ".join([f"#{name}" for name in moment.thread_names]);
            print(f"  {moment.kind:9} {moment.caption} {tags}".rstrip());
        }
        return 0;
    }
    if invocation.command == "plan" {
        intention = await set_intention(invocation.caption, invocation.date);
        print(f"Planned for {intention.target_date}: {intention.text}");
        return 0;
    }
    if invocation.command == "done" {
        day = await get_day(invocation.date);
        if not day.intention.id {
            print(f"No intention set for {day.date}");
            return 1;
        }
        intention = await toggle_intention(day.intention.id);
        state = "done" if intention.completed else "open";
        print(f"Intention for {intention.target_date} is now {state}: {intention.text}");
        return 0;
    }
    if invocation.command == "clear-plan" {
        day = await get_day(invocation.date);
        if not day.intention.id {
            print(f"No intention set for {day.date}");
            return 1;
        }
        await delete_intention(day.intention.id);
        print(f"Removed intention for {day.date}");
        return 0;
    }
    if invocation.command == "threads" {
        snapshot = await get_snapshot("");
        print("\nThreads\n");
        for thread in snapshot.threads {
            print(f"  {thread.name:24} {thread.moment_count} moments");
        }
        return 0;
    }
    return 2;
}

with entry:__main__ {
    sys.`exit(asyncio.run(dispatch(parse_args(sys.argv[1:]))));
}
