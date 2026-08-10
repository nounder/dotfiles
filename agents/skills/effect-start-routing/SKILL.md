---
name: effect-start-routing
description: Use when creating routes in effect-start applications using Route and HyperRoute APIs.
---

# effect-start Routing

## Route File Structure

Organize routes in a directory hierarchy:

```
src/routes/
├── route.tsx          # handles /
├── layer.tsx          # middleware for all routes
├── users/
│   ├── route.tsx      # handles /users
│   └── [id]/
│       └── route.tsx  # handles /users/:id
└── [[404]]/
    └── route.ts       # catch-all fallback
```

In `src/routes/tree.ts` maintain the tree:

```ts
// src/routes/tree.ts
import { Route } from "effect-start"

export default Route.tree({
  "*": await import("./layer.tsx").then(v => v.default),
  "/": await import("./route.tsx").then(v => v.default),
  "/users": await import("./users/route.tsx").then(v => v.default),
  "/users/:id": await import("./users/[id]/route.tsx").then(v => v.default),
})
```

Each `route.ts` or `route.tsx` file exports a default route:

```ts
// src/routes/users/route.tsx
import { Route } from "effect-start"

export default Route.get(
  Route.json({ users: [] })
)
```

## HTTP Methods

```ts
Route.get(...)     // GET
Route.post(...)    // POST
Route.put(...)     // PUT
Route.patch(...)   // PATCH
Route.del(...)     // DELETE
Route.head(...)    // HEAD
Route.options(...) // OPTIONS
Route.use(...)     // middleware (all methods)
```

Methods can be chained:

```ts
export default Route
  .get(Route.json({ message: "get" }))
  .post(Route.json({ message: "post" }))
```

## Response Formats

### Route.text()

Returns plain text (`Content-Type: text/plain`):

```ts
Route.get(Route.text("Hello, world!"))

Route.get(Route.text(function*(ctx) {
  return "Dynamic text"
}))
```

### Route.html()

Returns HTML (`Content-Type: text/html`):

```ts
Route.get(Route.html("<h1>Hello</h1>"))

Route.get(Route.html(function*(ctx) {
  return `<h1>Hello ${ctx.name}</h1>`
}))
```

### Route.json()

Returns JSON (`Content-Type: application/json`):

```ts
Route.get(Route.json({ message: "Hello" }))

Route.get(Route.json(function*(ctx) {
  const data = yield* fetchData()
  return { data }
}))
```

### Route.bytes()

Returns binary data (`Content-Type: application/octet-stream`):

```ts
Route.get(Route.bytes(new Uint8Array([1, 2, 3])))
```

### Route.render()

Full control over response format (no default Content-Type):

```ts
import { Entity, Route } from "effect-start"

Route.get(Route.render(function*(ctx) {
  return Entity.make("<custom>data</custom>", {
    headers: { "content-type": "application/xml" }
  })
}))
```

### Route.sse()

Server-sent events streaming:

```ts
import { Stream } from "effect"
import { Route } from "effect-start"

Route.get(
  Route.sse(
    Stream.fromIterable([
      { event: "message", data: "Hello" },
      { event: "message", data: "World" },
    ])
  )
)
```

## Entity.make() for Custom Responses

Use `Entity.make()` for full control over status, headers, and body:

```ts
import { Entity, Route } from "effect-start"

// Redirect
Route.get(Route.render(function*() {
  return Entity.make("", {
    status: 301,
    headers: { "location": "/new-path" }
  })
}))

// Custom headers
Route.get(Route.json(function*() {
  return Entity.make({ data: "value" }, {
    status: 201,
    headers: {
      "x-custom": "header",
      "cache-control": "no-cache"
    }
  })
}))

// Not found
Route.get(Route.render(function*() {
  return Entity.make("Not found", {
    status: 404,
    headers: { "content-type": "text/plain" }
  })
}))
```

## Layer Files (Middleware)

`layer.tsx` files apply middleware to all nested routes:

```ts
// src/routes/layer.tsx
import { Route } from "effect-start"
import { BunRoute } from "effect-start/bun"

export default Route.use(
  // Wrap HTML routes with a Bun HTML bundle (using a %children% placeholder)
  Route.html(
    BunRoute.bundle(() => import("../app.html"))
  ),
  // wrap all JSON responses in data property
  Route.json(function*(ctx, next) {
    const value = yield* next()
    return { data: value }
  })
)
```

The `next()` function calls the inner route handler.

## Handler Context

Handlers receive a context object with route descriptors and bindings:

```ts
Route.get(Route.json(function*(ctx) {
  // ctx.method - HTTP method
  // ctx.format - response format
  // ctx.request - raw request object
  return { method: ctx.method }
}))
```

### Schema Validation for Headers

```ts
import { Schema } from "effect"
import { Route } from "effect-start"

export default Route
  .use(
    Route.schemaHeaders(
      Schema.Struct({
        "authorization": Schema.String,
      })
    )
  )
  .get(
    Route.json(function*(ctx) {
      // ctx.authorization is typed as string
      return { auth: ctx.authorization }
    })
  )
```

### Schema Validation for URL Parameters

```ts
import { Schema } from "effect"
import { Route } from "effect-start"

// For route /users/:id
export default Route
  .use(
    Route.schemaUrlParams(
      Schema.Struct({
        "id": Schema.NumberFromString,
      })
    )
  )
  .get(
    Route.json(function*(ctx) {
      // ctx.id is typed as number
      return { userId: ctx.id }
    })
  )
```

## Path Patterns

```ts
Route.tree({
  "/": ...,              // exact match
  "/users": ...,         // literal path
  "/users/:id": ...,     // named parameter
  "/files/:path*": ...,  // zero or more segments
  "/docs/:slug+": ...,   // one or more segments
  "/:id?": ...,          // optional parameter
  "[[404]]": ...,        // catch-all (optional)
  "[...rest]": ...,      // catch-all (required)
})
```

## JSX Routes (with HyperRoute)

For JSX routes, use `HyperRoute` from `effect-start/hyper`:

```tsx
import { Route } from "effect-start"
import { HyperRoute } from "effect-start/hyper"

export default Route.get(
  HyperRoute.html(function*() {
    return (
      <div>
        <h1>Hello, world!</h1>
      </div>
    )
  })
)
```

Make sure `jsxImportSource` is set to `effect-start` in `tsconfig.json`

## SSE: Server-sent Events

Combine multiple streams for complex real-time updates:

```ts
import { Effect, Option, Stream, SubscriptionRef } from "effect"
import { Route } from "effect-start"

Route.get(
  Route.sse(
    Effect
      .gen(function*() {
        return Stream.make(1, 2, 3, 4).pipe(
          Stream.map((status) => ({
            event: "status",
            data: status,
          })),
        )
      ),
)
```

## Bun HTML bundle layout

Use `BunRoute.htmlBundle()` to wrap routes in an HTML layout:

```ts
import { Route } from "effect-start"
import { BunRoute } from "effect-start/bun"

export default Route.tree({
  "*": Route.use(
    BunRoute.htmlBundle(() => import("./app.html")),
  ),
  "/": Route.get(Route.html("<h1>Content goes here</h1>")),
})
```
