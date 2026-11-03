import Foundation

@main
enum ActivitySignalTests {
    static func main() {
        var failed = 0
        func check(_ name: String, _ tail: String, _ expected: Bool) {
            let got = ActivitySignals.agyIsWorking(tail: tail)
            if got != expected {
                failed += 1
                fputs("FAIL \(name): got \(got), expected \(expected)\n", stderr)
            }
        }

        check("final answer", line(
            #"{"step_index":3,"source":"MODEL","type":"PLANNER_RESPONSE","status":"DONE","content":"The answer is 1234."}"#
        ), false)

        check("planner still calling tools", line(
            #"{"step_index":2,"source":"MODEL","type":"PLANNER_RESPONSE","status":"DONE","tool_calls":[{"name":"list_dir","args":{}}]}"#
        ), true)

        check("step still running", line(
            #"{"step_index":4,"source":"MODEL","type":"PLANNER_RESPONSE","status":"RUNNING"}"#
        ), true)

        check("user just asked", """
        \(line(#"{"step_index":0,"source":"USER_EXPLICIT","type":"USER_INPUT","status":"DONE","content":"hi"}"#))
        \(line(#"{"step_index":1,"source":"SYSTEM","type":"CONVERSATION_HISTORY","status":"DONE"}"#))
        """, true)

        check("tool result, model has not answered", line(
            #"{"step_index":3,"source":"MODEL","type":"RUN_COMMAND","status":"DONE","content":"ok"}"#
        ), true)

        check("finished reply hidden behind a checkpoint", """
        \(line(#"{"step_index":8,"source":"MODEL","type":"PLANNER_RESPONSE","status":"DONE","content":"done","tool_calls":[]}"#))
        \(line(#"{"step_index":9,"source":"SYSTEM","type":"CHECKPOINT","status":"DONE"}"#))
        """, false)

        check("cancelled turn", line(
            #"{"step_index":2,"source":"MODEL","type":"PLANNER_RESPONSE","status":"CANCELLED"}"#
        ), false)

        check("error while a tool call is being fixed", line(
            #"{"step_index":6,"source":"SYSTEM","type":"ERROR_MESSAGE","status":"DONE","error":"invalid tool call"}"#
        ), true)

        if failed > 0 {
            fputs("\(failed) failed\n", stderr)
            exit(1)
        }
        print("agy signals ok")
    }

    private static func line(_ json: String) -> String {
        json
    }
}
