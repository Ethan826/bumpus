// Hand-written Go for FX001 Task 1: the runtime shapes of effects design §4
// (context list, targeted aborts, the lifted `handle` helper, cleanup per §3
// and the defect report of §5). Shared prelude of every probe program; the
// compiler will emit this text only when a program uses it.
//
// Markers are non-zero-sized (Go lets distinct zero-sized variables share an
// address) and compared by pointer only. `recover` is called directly in
// each deferred function that uses it.
export const header = 'package main\n\nimport (\n\t"fmt"\n\t"os"\n'
  + '\t"strings"\n\t"time"\n)\n\nvar _ = time.Now\n';

export const runtime = String.raw`
const (
	keyLog = 1
	keyFail = 2
	keyOther = 3
)

var keyNames = map[int]string{keyLog: "Log", keyFail: "Fail", keyOther: "Other"}

type bumpusMarker struct{ id uint64 }
type bumpusAbort struct {
	target  *bumpusMarker
	payload any
}
type bumpusCtx struct {
	key     int
	handler any
	outer   *bumpusCtx
	marker  *bumpusMarker
}
type bumpusDefect struct{ lines []string }
type bumpusShown interface{ Shown() (string, string) }
type logHandler struct{ log func(ctx *bumpusCtx, s string) int }

var bumpusNext uint64

func bumpusInstall(outer *bumpusCtx, key int, handler any) *bumpusCtx {
	return &bumpusCtx{key: key, handler: handler, outer: outer}
}

// A handle's frame: a fresh marker per frame, never shared.
func bumpusFrame(outer *bumpusCtx, key int) *bumpusCtx {
	bumpusNext++
	return &bumpusCtx{key: key, outer: outer, marker: &bumpusMarker{id: bumpusNext}}
}

func bumpusFind(ctx *bumpusCtx, key int) *bumpusCtx {
	for ctx != nil && ctx.key != key {
		ctx = ctx.outer
	}
	if ctx == nil {
		panic(&bumpusDefect{[]string{"no handler for " + keyNames[key]}})
	}
	return ctx
}

// The clause runs with the frame's outer context (design §3).
func performLog(ctx *bumpusCtx, s string) int {
	frame := bumpusFind(ctx, keyLog)
	return frame.handler.(*logHandler).log(frame.outer, s)
}

func bumpusFail(ctx *bumpusCtx, key int, payload any) {
	panic(&bumpusAbort{target: bumpusFind(ctx, key).marker, payload: payload})
}

func bumpusOwns(markers []*bumpusMarker, target *bumpusMarker) bool {
	for _, m := range markers {
		if m == target {
			return true
		}
	}
	return false
}

// Recovers only aborts aimed at its own markers; the failure clause runs
// after it returns, in the handle's context.
func bumpusHandle(markers []*bumpusMarker, body func() int) (result int, caught *bumpusAbort) {
	defer func() {
		if r := recover(); r != nil {
			if a, ok := r.(*bumpusAbort); ok && bumpusOwns(markers, a.target) {
				caught = a
				return
			}
			panic(r)
		}
	}()
	return body(), nil
}

type bumpusPending struct {
	first any
	later []any
}

func bumpusEscape(s string) string { return strings.ReplaceAll(s, "\n", "\\n") }

func bumpusCauses(r any) []string {
	switch v := r.(type) {
	case *bumpusAbort:
		if s, ok := v.payload.(bumpusShown); ok {
			t, text := s.Shown()
			return []string{"fail(" + t + "): " + bumpusEscape(text)}
		}
		return []string{fmt.Sprintf("fail(Int): %v", v.payload)}
	case *bumpusDefect:
		return v.lines
	}
	return []string{"crash: " + bumpusEscape(fmt.Sprint(r))}
}

func bumpusCrash(text string) { panic(&bumpusDefect{[]string{"crash: " + bumpusEscape(text)}}) }

// One cause while nothing else fails (an abort stays an abort); a defect
// carrying every cause, in execution order, once a cleanup also fails.
func (p *bumpusPending) value() any {
	if len(p.later) == 0 {
		return p.first
	}
	lines := bumpusCauses(p.first)
	for _, l := range p.later {
		lines = append(lines, bumpusCauses(l)...)
	}
	return &bumpusDefect{lines}
}

func bumpusRunCleanup(state *bumpusPending, cleanup func()) {
	defer func() {
		if r := recover(); r != nil {
			if state.first == nil {
				state.first = r
			} else {
				state.later = append(state.later, r)
			}
		}
	}()
	cleanup()
}

// Deferred directly (defer bumpusCleanup(&state, f)) so its recover works.
// The first exit panic becomes the pending cause; later panics (from the
// re-raise of that cause) are ignored; remaining cleanup still runs.
func bumpusCleanup(state *bumpusPending, cleanup func()) {
	if r := recover(); r != nil && state.first == nil {
		state.first = r
	}
	bumpusRunCleanup(state, cleanup)
	if state.first != nil {
		panic(state.value())
	}
}

func bumpusMain(run func()) {
	defer func() {
		if r := recover(); r != nil {
			lines := bumpusCauses(r)
			for i := 1; i < len(lines); i++ {
				lines[i] = "cleanup failed: " + lines[i]
			}
			fmt.Fprintln(os.Stderr, strings.Join(lines, "\n"))
			os.Exit(1)
		}
	}()
	run()
}
`;
