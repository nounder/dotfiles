---
name: effect-testing
description: Use when writing tests for Effect.ts code
---

## Error Testing

```ts
test.it("should fail with ValidationError", async () => {
  const program = Effect.gen(function* () {
    const result = yield* Effect.exit(operation("invalid"))

    if (result._tag === "Failure") {
      test.expect(ValidationError.isValidationError(result.cause)).toBe(true)
      const error = result.cause as ValidationError
      test.expect(error.field).toBe("input")
    } else {
      test.fail("Expected operation to fail")
    }
  })

  await Effect.runPromise(program)
})
```

### Time-sensitive Testing

```ts
import * as TestClock from "effect/TestClock"

test.it("should handle delay", async () => {
  const program = Effect.gen(function* () {
    const fiber = yield* Effect.fork(
      Effect.gen(function* () {
        yield* Effect.sleep("5 seconds")
        return "completed"
      }),
    )

    // Advance test clock (not wall clock)
    yield* TestClock.adjust("5 seconds")

    const result = yield* Effect.Fiber.join(fiber)
    return result
  })

  const result = await Effect.runPromise(program)
  test.expect(result).toBe("completed")
})
```

## Commands

```sh
tsc                # Type check
bun test <file>    # Test specific file
bun test           # All tests
```
