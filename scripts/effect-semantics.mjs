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

func markers(f *bumpusCtx) []*bumpusMarker { return []*bumpusMarker{f.marker} }

func clauseMode() {
	outer := bumpusInstall(nil, keyLog, &logHandler{func(c *bumpusCtx, s string) int { say("outer got " + s); return 10 }})
	inner := bumpusInstall(outer, keyLog, &logHandler{func(c *bumpusCtx, s string) int {
		say("inner clause " + s)
		return 1 + performLog(c, "fwd:"+s)
	}})
	say(fmt.Sprint("result ", performLog(inner, "hi")))
}

// A lifted block helper with two defers (registered d1 then d2).
func block(ctx *bumpusCtx, body func()) {
	var st bumpusPending
	defer bumpusCleanup(&st, func() { say("d1") })
	defer bumpusCleanup(&st, func() { say("d2") })
	body()
}

func abortMode() {
	fa := bumpusFrame(nil, keyFail)
	r, a := bumpusHandle(markers(fa), func() int {
		fo := bumpusFrame(fa, keyOther)
		bumpusHandle(markers(fo), func() int { bumpusFail(fo, keyFail, 7); return 0 })
		say("unreachable")
		return 0
	})
	say(fmt.Sprint("A: ", r, " caught ", a.payload))
	// the failing body targets the outer frame across an inner same-key handle
	fb := bumpusFrame(fa, keyFail)
	_, b := bumpusHandle(markers(fa), func() int {
		bumpusHandle(markers(fb), func() int { bumpusFail(fb, keyFail, 8); return 0 }) // caught by fb
		say("B: inner caught its own")
		bumpusHandle(markers(fb), func() int { bumpusFail(fa, keyFail, 9); return 0 }) // aimed at fa
		say("unreachable")
		return 0
	})
	say(fmt.Sprint("B: outer caught ", b.payload))
	// a clause installed outside an inner handle that fails is not caught by it
	_, c := bumpusHandle(markers(fa), func() int {
		_, inner := bumpusHandle(markers(fb), func() int { bumpusFail(fb, keyFail, 1); return 0 })
		say("C: clause runs after helper")
		bumpusFail(fb.outer, keyFail, inner.payload.(int)+98) // clause context = fb.outer
		return 0
	})
	say(fmt.Sprint("C: outer caught ", c.payload))
	// two nested blocks unwind innermost first (d2 d1 per block)
	_, d := bumpusHandle(markers(fa), func() int {
		block(fa, func() { block(fa, func() { say("body"); bumpusFail(fa, keyFail, 5) }) })
		return 0
	})
	say(fmt.Sprint("D: caught ", d.payload))
	// cleanup handles a failure internally while an abort is pending
	_, e := bumpusHandle(markers(fa), func() int {
		var st bumpusPending
		defer bumpusCleanup(&st, func() {
			g := bumpusFrame(fa, keyFail)
			_, h := bumpusHandle(markers(g), func() int { bumpusFail(g, keyFail, 3); return 0 })
			say(fmt.Sprint("E: cleanup handled ", h.payload))
		})
		bumpusFail(fa, keyFail, 4)
		return 0
	})
	say(fmt.Sprint("E: abort continued ", e.payload))
}

func markersMode() {
	seen := map[*bumpusMarker]bool{}
	var keep []*bumpusMarker
	for i := 0; i < 1000; i++ {
		m := bumpusFrame(nil, keyFail).marker
		keep = append(keep, m)
		seen[m] = true
	}
	say(fmt.Sprint("distinct ", len(seen), " of ", len(keep)))
}

func reportMode() {
	fa := bumpusFrame(nil, keyFail)
	var st bumpusPending
	defer bumpusCleanup(&st, func() { say("d1"); bumpusCrash("bad\nline") })
	defer bumpusCleanup(&st, func() { say("d2"); bumpusFail(fa, keyFail, releaseError{}) })
	say("body")
	bumpusFail(fa, keyFail, dbError{3})
}

func normalMode() {
	var st bumpusPending
	defer bumpusCleanup(&st, func() { say("d1"); bumpusCrash("b") })
	defer bumpusCleanup(&st, func() { say("d2"); bumpusCrash("a") })
	say("body")
}

func defectMode() {
	fa := bumpusFrame(nil, keyFail)
	bumpusHandle(markers(fa), func() int {
		var st bumpusPending
		defer bumpusCleanup(&st, func() { say("cleanup ran") })
		bumpusCrash("boom")
		return 0
	})
	say("unreachable")
}

func guardMode() { performLog(nil, "x") }

func main() {
	modes := map[string]func(){"clause": clauseMode, "abort": abortMode, "markers": markersMode,
		"report": reportMode, "normal": normalMode, "defect": defectMode, "guard": guardMode}
	bumpusMain(func() { defer flush(); modes[os.Args[1]]() })
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
