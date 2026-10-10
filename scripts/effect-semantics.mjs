// Go program of FX001 Task 1 Step 2: semantic checks of the runtime shapes
// (effects design §3, §4, §5). Each mode prints a transcript (stdout) and
// may end in a defect report (stderr, exit 1); `semanticCases` holds what
// the semantics require, written out independently of the Go.
import { header, runtime } from './effect-runtime.mjs';

const body = String.raw`
type dbError struct{ n int }
type releaseError struct{}

func (e dbError) Shown() (string, string)      { return "DbError", fmt.Sprintf("Timeout(%d)", e.n) }
func (e releaseError) Shown() (string, string) { return "ReleaseError", "Busy" }

var out []string

func say(s string) { out = append(out, s) }

func flush() { fmt.Println(strings.Join(out, "\n")) }

func markers(f *waxwingCtx) []*waxwingMarker { return []*waxwingMarker{f.marker} }

func clauseMode() {
	outer := waxwingInstall(nil, keyLog, &logHandler{func(c *waxwingCtx, s string) int { say("outer got " + s); return 10 }})
	inner := waxwingInstall(outer, keyLog, &logHandler{func(c *waxwingCtx, s string) int {
		say("inner clause " + s)
		return 1 + performLog(c, "fwd:"+s)
	}})
	say(fmt.Sprint("result ", performLog(inner, "hi")))
}

// A lifted block helper with two defers (registered d1 then d2).
func block(ctx *waxwingCtx, body func()) {
	var st waxwingPending
	defer waxwingCleanup(&st, func() { say("d1") })
	defer waxwingCleanup(&st, func() { say("d2") })
	body()
}

func abortMode() {
	fa := waxwingFrame(nil, keyFail)
	r, a := waxwingHandle(markers(fa), func() int {
		fo := waxwingFrame(fa, keyOther)
		waxwingHandle(markers(fo), func() int { waxwingFail(fo, keyFail, 7); return 0 })
		say("unreachable")
		return 0
	})
	say(fmt.Sprint("A: ", r, " caught ", a.payload))
	// the failing body targets the outer frame across an inner same-key handle
	fb := waxwingFrame(fa, keyFail)
	_, b := waxwingHandle(markers(fa), func() int {
		waxwingHandle(markers(fb), func() int { waxwingFail(fb, keyFail, 8); return 0 }) // caught by fb
		say("B: inner caught its own")
		waxwingHandle(markers(fb), func() int { waxwingFail(fa, keyFail, 9); return 0 }) // aimed at fa
		say("unreachable")
		return 0
	})
	say(fmt.Sprint("B: outer caught ", b.payload))
	// a clause installed outside an inner handle that fails is not caught by it
	_, c := waxwingHandle(markers(fa), func() int {
		_, inner := waxwingHandle(markers(fb), func() int { waxwingFail(fb, keyFail, 1); return 0 })
		say("C: clause runs after helper")
		waxwingFail(fb.outer, keyFail, inner.payload.(int)+98) // clause context = fb.outer
		return 0
	})
	say(fmt.Sprint("C: outer caught ", c.payload))
	// two nested blocks unwind innermost first (d2 d1 per block)
	_, d := waxwingHandle(markers(fa), func() int {
		block(fa, func() { block(fa, func() { say("body"); waxwingFail(fa, keyFail, 5) }) })
		return 0
	})
	say(fmt.Sprint("D: caught ", d.payload))
	// cleanup handles a failure internally while an abort is pending
	_, e := waxwingHandle(markers(fa), func() int {
		var st waxwingPending
		defer waxwingCleanup(&st, func() {
			g := waxwingFrame(fa, keyFail)
			_, h := waxwingHandle(markers(g), func() int { waxwingFail(g, keyFail, 3); return 0 })
			say(fmt.Sprint("E: cleanup handled ", h.payload))
		})
		waxwingFail(fa, keyFail, 4)
		return 0
	})
	say(fmt.Sprint("E: abort continued ", e.payload))
}

func markersMode() {
	seen := map[*waxwingMarker]bool{}
	var keep []*waxwingMarker
	for i := 0; i < 1000; i++ {
		m := waxwingFrame(nil, keyFail).marker
		keep = append(keep, m)
		seen[m] = true
	}
	say(fmt.Sprint("distinct ", len(seen), " of ", len(keep)))
}

func reportMode() {
	fa := waxwingFrame(nil, keyFail)
	var st waxwingPending
	defer waxwingCleanup(&st, func() { say("d1"); waxwingCrash("bad\nline") })
	defer waxwingCleanup(&st, func() { say("d2"); waxwingFail(fa, keyFail, releaseError{}) })
	say("body")
	waxwingFail(fa, keyFail, dbError{3})
}

func normalMode() {
	var st waxwingPending
	defer waxwingCleanup(&st, func() { say("d1"); waxwingCrash("b") })
	defer waxwingCleanup(&st, func() { say("d2"); waxwingCrash("a") })
	say("body")
}

func defectMode() {
	fa := waxwingFrame(nil, keyFail)
	waxwingHandle(markers(fa), func() int {
		var st waxwingPending
		defer waxwingCleanup(&st, func() { say("cleanup ran") })
		waxwingCrash("boom")
		return 0
	})
	say("unreachable")
}

func guardMode() { performLog(nil, "x") }

func main() {
	modes := map[string]func(){"clause": clauseMode, "abort": abortMode, "markers": markersMode,
		"report": reportMode, "normal": normalMode, "defect": defectMode, "guard": guardMode}
	waxwingMain(func() { defer flush(); modes[os.Args[1]]() })
}
`;

export const semanticProgram = header + runtime + body;

const lines = (...text) => text.join('\n') + '\n';
export const semanticCases = [
  { mode: 'clause', status: 0, stderr: '',
    stdout: lines('inner clause hi', 'outer got fwd:hi', 'result 11') },
  { mode: 'abort', status: 0, stderr: '', stdout: lines(
    'A: 0 caught 7', 'B: inner caught its own', 'B: outer caught 9',
    'C: clause runs after helper', 'C: outer caught 99', 'body', 'd2', 'd1', 'd2', 'd1',
    'D: caught 5', 'E: cleanup handled 3', 'E: abort continued 4') },
  { mode: 'markers', status: 0, stderr: '', stdout: 'distinct 1000 of 1000\n' },
  { mode: 'report', status: 1, stdout: lines('body', 'd2', 'd1'),
    stderr: lines('fail(DbError): Timeout(3)',
      'cleanup failed: fail(ReleaseError): Busy',
      'cleanup failed: crash: bad\\nline') },
  { mode: 'normal', status: 1, stdout: lines('body', 'd2', 'd1'),
    stderr: lines('crash: a', 'cleanup failed: crash: b') },
  { mode: 'defect', status: 1, stdout: lines('cleanup ran'),
    stderr: lines('crash: boom') },
  { mode: 'guard', status: 1, stdout: '\n', stderr: lines('no handler for Log') }
];
