# User requirements: operational addendum to the concurrency-foundations assessment (2026-10-10, verbatim; Task 9 continues per the user's clarification)

Add the following to the concurrency-foundations assessment requested for the stopping point after Task 8. Keep this as design work and durable handoff; do not begin implementation.
Consider Gleam/OTP's operational model alongside the CS-theory investigation. Types and effects may prevent invalid interactions, but Waxwing also needs an account of failure containment, recovery, overload, and debugging.
In particular:

* Structured concurrency versus supervision. Distinguish scoped child tasks from long-lived services that may restart. Consider restart dependencies, restart limits, and ownership of resources across restarts.
* Defect boundaries. Task 8 currently specifies an uncatchable defect followed by program termination. Determine how that contract could evolve for isolated tasks/services: cleanup, task termination, supervisor notification, and escalation to process termination. Do not silently change the approved Task 8 behavior; identify any future compatibility issue.
* State ownership and service execution. Effects describe required operations, but do not determine who owns the implementing state or serializes access. Compare task-local handlers, typed actors/message passing, and explicitly shared capabilities. Explain how ownership, region effects, or lawful abstractions could make each model safer or simpler.
* Overload and communication. Include bounded queues, backpressure, deadlines, and request/reply cancellation. Typed messages alone do not prove deadlock freedom, determinism, or bounded resource use.
* Observability. Identify the minimum runtime support needed to inspect task trees, blocked operations, queues, cancellation, and failure causes. Treat this as part of the concurrency design.
* Host boundaries. Consider exported functions and callbacks as well as foreign imports: capability ownership, callback lifetimes, cancellation, typed failures, and defects crossing Go or other host frames.
* Practical delivery. Record tooling implications—debugging, editor support, package/build integration—without expanding the current implementation milestone.

Use Gleam/OTP as a conceptual comparison, not a mandate to adopt BEAM or reproduce OTP. Consult only a bounded set of primary sources, including:
https://gleam-otp.hexdocs.pm/gleam/otp/actor.html
https://gleam-otp.hexdocs.pm/gleam/otp/static_supervisor.html
Connect these operational concerns to the earlier theory assessment. For each recommended abstraction, state what the type/effect system guarantees, what remains a runtime responsibility, and what remains an application policy. Identify which contracts deserve decisions now and which mechanisms can wait.
