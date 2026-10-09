// Go programs of FX001 Task 1 Step 3 (effects design §4, §5): measurement
// loops and the generated lifted-helper program. Every measured loop folds
// its results into a checksum printed with the elapsed nanoseconds
// ("<ns> <checksum>"), and `expected*` recompute it independently.
import { header, runtime } from './effect-runtime.mjs';

export const installs = 1_000_000;
export const performs = 1_000_000;
export const deep = 10_000;
export const frames = 1_000;
export const caughtAborts = 100_000;

const body = String.raw`
type opHandler struct{ run func(ctx *bumpusCtx, x int) int }

var sinkCtx *bumpusCtx
var sinkCount int

func timed(f func() int) {
	start := time.Now()
	sum := f()
	fmt.Println(time.Since(start).Nanoseconds(), sum)
}

func install(n int) int {
	base := &bumpusCtx{key: 1}
	sum := 0
	for i := 0; i < n; i++ {
		c := bumpusInstall(base, i&7, nil)
		sinkCtx = c
		sum += c.key
	}
	return sum
}

// A context of the given depth: the frame at depth d has key d, so a
// perform with key d walks d links before calling its clause.
func lookup(depth, n int) int {
	var ctx *bumpusCtx
	clause := &opHandler{func(c *bumpusCtx, x int) int { return x + 1 }}
	for d := 10000; d >= 1; d-- {
		ctx = bumpusInstall(ctx, d, clause)
	}
	sum := 0
	for i := 0; i < n; i++ {
		f := bumpusFind(ctx, depth)
		sum += f.handler.(*opHandler).run(f.outer, i) + f.key
	}
	return sum
}

func deepHandles(ctx *bumpusCtx, n int) int {
	sinkCount++
	if n == 0 {
		bumpusFail(ctx, keyFail, 5)
	}
	fo := bumpusFrame(ctx, keyOther)
	r, _ := bumpusHandle([]*bumpusMarker{fo.marker}, func() int { return deepHandles(fo, n-1) + 1 })
	return r
}

func deepCleanups(ctx *bumpusCtx, n int) int {
	var st bumpusPending
	defer bumpusCleanup(&st, func() { sinkCount++ })
	if n == 0 {
		bumpusFail(ctx, keyFail, 5)
	}
	return deepCleanups(ctx, n-1) + 1
}

func unwind(cleanups bool, n int) int {
	fa := bumpusFrame(nil, keyFail)
	_, a := bumpusHandle([]*bumpusMarker{fa.marker}, func() int {
		if cleanups {
			return deepCleanups(fa, n)
		}
		return deepHandles(fa, n)
	})
	return a.payload.(int) + sinkCount
}

func caught(n int) int {
	fa := bumpusFrame(nil, keyFail)
	sum := 0
	for i := 0; i < n; i++ {
		_, a := bumpusHandle([]*bumpusMarker{fa.marker}, func() int { bumpusFail(fa, keyFail, i); return 0 })
		sum += a.payload.(int)
	}
	return sum
}

func main() {
	switch os.Args[1] {
	case "install":
		timed(func() int { return install(1000000) })
	case "lookup":
		var depth int
		fmt.Sscan(os.Args[2], &depth)
		timed(func() int { return lookup(depth, 1000000) })
	case "unwindHandles":
		timed(func() int { return unwind(false, 1000) })
	case "unwindCleanups":
		timed(func() int { return unwind(true, 1000) })
	case "caught":
		timed(func() int { return caught(100000) })
	}
}
`;

export const measureProgram = header + runtime + body;

const sumTo = n => (n * (n - 1)) / 2;
export const expected = {
  install: Array.from({ length: installs }, (_, i) => i & 7)
    .reduce((a, b) => a + b, 0),
  lookup: depth => performs * (depth + 1) + sumTo(performs),
  // payload 5 plus one count per frame (n + 1 frames reach the abort).
  unwindHandles: 5 + frames + 1,
  unwindCleanups: 5 + frames + 1,
  caught: sumTo(caughtAborts)
};

// `count` lifted helpers, each a block with two defers around a `handle`
// whose body performs Log or fails; main folds every result and the
// cleanup effects into one checksum. `seed` defeats Go's build cache so
// every repetition recompiles.
const helper = i => String.raw`
func blk_${i}(ctx *bumpusCtx, x int) int {
	var st bumpusPending
	defer bumpusCleanup(&st, func() { bumpusSink += ${i} })
	defer bumpusCleanup(&st, func() { bumpusSink += ${2 * i} })
	f := bumpusFrame(ctx, keyFail)
	r, a := bumpusHandle([]*bumpusMarker{f.marker}, func() int {
		if x < 0 {
			bumpusFail(f, keyFail, x)
		}
		return performLog(f, "m") + x + ${i}
	})
	if a != nil {
		return a.payload.(int) + ${i}
	}
	return r
}
`;

export const helperProgram = (count, seed) => {
  const names = Array.from({ length: count }, (_, i) => `blk_${i},`);
  return header + runtime + `\n// seed ${seed}\nvar bumpusSink int\n`
    + Array.from({ length: count }, (_, i) => helper(i)).join('')
    + `\nvar helpers = []func(*bumpusCtx, int) int{\n${names.join('\n')}\n}\n`
    + String.raw`
func main() {
	ctx := bumpusInstall(nil, keyLog, &logHandler{func(c *bumpusCtx, s string) int { return 1 }})
	sum := 0
	for i, h := range helpers {
		sum += h(ctx, i%5-1)
	}
	fmt.Println(sum + bumpusSink)
}
`;
};

export const expectedHelpers = count => {
  let sum = 0;
  for (let i = 0; i < count; i++) {
    sum += (i % 5 === 0 ? i - 1 : (i % 5) + i) + 3 * i;
  }
  return sum;
};
