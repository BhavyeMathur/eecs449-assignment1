"""Argument-contract tests for the Daybook command-line interface."""

import from cli.main { parse_args }

test "log arguments retain kind date and thread input" {
    invocation = parse_args([
        "log", "Reviewed the project", "--kind", "work",
        "--thread", "Coursework", "--thread", "Small wins",
        "--date", "2040-04-05"
    ]);
    assert invocation.command == "log";
    assert invocation.caption == "Reviewed the project";
    assert invocation.kind == "work";
    assert invocation.threads == ["Coursework", "Small wins"];
    assert invocation.date == "2040-04-05";
}

test "planning commands retain their target day" {
    plan = parse_args(["plan", "Finish the write-up", "--date", "2040-04-06"]);
    done = parse_args(["done", "--date", "2040-04-06"]);
    clear_plan = parse_args(["clear-plan", "--date", "2040-04-06"]);
    assert plan.command == "plan" and plan.caption == "Finish the write-up";
    assert done.command == "done" and done.date == "2040-04-06";
    assert clear_plan.command == "clear-plan" and clear_plan.date == "2040-04-06";
}
