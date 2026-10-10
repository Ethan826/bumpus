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

type waxwingMarker struct{ id uint64 }
type waxwingAbort struct {
	target  *waxwingMarker
	payload any
}
type waxwingCtx struct {
	key     int
	handler any
	outer   *waxwingCtx
	marker  *waxwingMarker
}
type waxwingDefect struct{ lines []string }
type waxwingShown interface{ Shown() (string, string) }
type logHandler struct{ log func(ctx *waxwingCtx, s string) int }

var waxwingNext uint64

func waxwingInstall(outer *waxwingCtx, key int, handler any) *waxwingCtx {
	return &waxwingCtx{key: key, handler: handler, outer: outer}
}

// A handle's frame: a fresh marker per frame, never shared.
func waxwingFrame(outer *waxwingCtx, key int) *waxwingCtx {
	waxwingNext++
	return &waxwingCtx{key: key, outer: outer, marker: &waxwingMarker{id: waxwingNext}}
}

func waxwingFind(ctx *waxwingCtx, key int) *waxwingCtx {
	for ctx != nil && ctx.key != key {
		ctx = ctx.outer
	}
	if ctx == nil {
		panic(&waxwingDefect{[]string{"no handler for " + keyNames[key]}})
	}
	return ctx
}

// The clause runs with the frame's outer context (design §3).
func performLog(ctx *waxwingCtx, s string) int {
	frame := waxwingFind(ctx, keyLog)
	return frame.handler.(*logHandler).log(frame.outer, s)
}

func waxwingFail(ctx *waxwingCtx, key int, payload any) {
	panic(&waxwingAbort{target: waxwingFind(ctx, key).marker, payload: payload})
}

func waxwingOwns(markers []*waxwingMarker, target *waxwingMarker) bool {
	for _, m := range markers {
		if m == target {
			return true
		}
	}
	return false
}

// Recovers only aborts aimed at its own markers; the failure clause runs
// after it returns, in the handle's context.
func waxwingHandle(markers []*waxwingMarker, body func() int) (result int, caught *waxwingAbort) {
	defer func() {
		if r := recover(); r != nil {
			if a, ok := r.(*waxwingAbort); ok && waxwingOwns(markers, a.target) {
				caught = a
				return
			}
			panic(r)
		}
	}()
	return body(), nil
}

type waxwingPending struct {
	first any
	later []any
}

func waxwingEscape(s string) string { return strings.ReplaceAll(s, "\n", "\\n") }

func waxwingCauses(r any) []string {
	switch v := r.(type) {
	case *waxwingAbort:
		if s, ok := v.payload.(waxwingShown); ok {
			t, text := s.Shown()
			return []string{"fail(" + t + "): " + waxwingEscape(text)}
		}
		return []string{fmt.Sprintf("fail(Int): %v", v.payload)}
	case *waxwingDefect:
		return v.lines
	}
	return []string{"crash: " + waxwingEscape(fmt.Sprint(r))}
}

func waxwingCrash(text string) { panic(&waxwingDefect{[]string{"crash: " + waxwingEscape(text)}}) }

// One cause while nothing else fails (an abort stays an abort); a defect
// carrying every cause, in execution order, once a cleanup also fails.
func (p *waxwingPending) value() any {
	if len(p.later) == 0 {
		return p.first
	}
	lines := waxwingCauses(p.first)
	for _, l := range p.later {
		lines = append(lines, waxwingCauses(l)...)
	}
	return &waxwingDefect{lines}
}

func waxwingRunCleanup(state *waxwingPending, cleanup func()) {
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

// Deferred directly (defer waxwingCleanup(&state, f)) so its recover works.
// The first exit panic becomes the pending cause; later panics (from the
// re-raise of that cause) are ignored; remaining cleanup still runs.
func waxwingCleanup(state *waxwingPending, cleanup func()) {
	if r := recover(); r != nil && state.first == nil {
		state.first = r
	}
	waxwingRunCleanup(state, cleanup)
	if state.first != nil {
		panic(state.value())
	}
}

func waxwingMain(run func()) {
	defer func() {
		if r := recover(); r != nil {
			lines := waxwingCauses(r)
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
