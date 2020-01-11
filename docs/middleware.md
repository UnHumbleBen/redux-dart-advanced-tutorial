# Middleware

You've seen middleware action in the the [Async Actions](async_actions.md) example.
If you've ever used server-side libraries like
[Shelf](https://pub.dev/packages/shelf), you
were also probably already familiar with the concept of
_middleware_.  In these frameworks, middleware is some
code you can put between the framework receiving a request,
adn the framework generating a response. For example,
Shelf middleware may add CORS headers, logging, compression,
and more. The best feature of middleware is that it's
composable in a chain. You can use multiple independent
third-party middleware in a single project.

Redux middleware solves different problems than Shelf middleware,
but in a conceptually similar way.
__It provides a third-party extension point between dispatching
an action, and the moment it reaches the reducer__.
People use Redux for logging, crash reporting, talking to
an asynchronous API, routing and more.

This article is divided into an in-dept intro to help you
grok the concept, and [a few practical examples](#seven-examples)
to show the power of middleware at the very end. You may
find it helpful to switch back and forth between them, as you
flip between feeling bored and inspired.

## Understanding Middleware

While middleware can be used for a vareity of things,
including asynchronous API calls, it's really important that you
understand where it comes from. We'll guide you through the thought
process leading to middleware, by using logging and crash
reporting as examples.

### Problem: Logging

One of the benefits of Redux is that it makes state changes
predictable and transparent. Every time an action is dispatched,
the new state is computed and saved. The state cannot change by
itself, it can only change as a consequence of a specific action.

Wouldn't it be nice if we logged every action that happens in the
app, together with the state computer after it? When something
goes wrong, we can look back at our log, and figure out which
corrupted the state.

```
dispatching {type: ADD_TODO, value: Use Redux}
next state AppState {visibleTodoFilter: VisibilityFilter.showAll, todos: [Todo {completed: false, text: "Use Redux"}]}
dispatching {type: ADD_TODO, value: Learn about middleware}
next state AppState {visibleTodoFilter: VisibilityFilter.showAll, todos: [Todo {completed: false, text: "Use Redux"}, Todo {completed: false, text: "Learn about middleware"}]}
dispatching {type: TOGGLE_TODO, value: 0}
next state AppState {visibleTodoFilter: VisibilityFilter.showAll, todos: [Todo {completed: true, text: "Use Redux"}, Todo {completed: false, text: "Learn about middleware"}]}
dispatching {type: SET_VISIBILITY_FILTER, value: SHOW_COMPLETED}
next state AppState {visibleTodoFilter: VisibilityFilter.showCompleted, todos: [Todo {completed: true, text: "Use Redux"}, Todo {completed: false, text: "Learn about middleware"}]}
```

How do we approach this with Redux?

## Attempt #1: Logging Manually

The most naïve approach is just to log the action and the next
state yourself every time you call [`store.dispatch(action)`](https://pub.dev/documentation/redux/latest/redux/Store/dispatch.html)
It's not really a solution, but just a first step towards
understanding hte problem.

> __Note__
>
> If you're using [OverReact Redux](https://github.com/Workiva/over_react/blob/master/doc/over_react_redux_documentation.md)
> or similar bindings, you likely won't have direct access to
> the store instance in your components. For the next few
> paragraphs, just assume you pass the store down explicitly.

Say, you call this when creating a todo:

```dart 
store.dispatch(AddTodo('Use Redux'));
```

To log the action and state, you can change it to something like
this:

```dart
var action = AddTodo('Use Redux');

print('dispatching ${action}');
store.dispatch(action);
print('next state ${store.state}');
```

This produces the desired effect, but you wouldn't want to do
it every time.

## Attempt #2: Wrapping Dispatch
You can extract logging into a function:

```dart
void dispatchAndLog(Store<AppState> store, dynamic action) {
  print('dispatching ${action}');
  store.dispatch(action);
  print('next state ${store.state}');
}
```

You can then use it everywhere instead of `store.dispatch()`
```dart
dispatchAndLog(store, AddTodo('Use Redux'));
```

We could end this here, but it's not very convenient
to import a special function every time.

## Attempt 3: Monkeypatching Dispatch
What if we just replace the `dispatch` function on the store
instance? The Redux store is just a plain object with
[a few methods](https://pub.dev/documentation/redux/latest/redux/Store-class.html),
and we're writing in Dart, so we can just wrap the `dispatch`
implementation:

```dart
class WrappedStore {
  void Function(dynamic) dispatch = store.dispatch;
  AppState get state => store.state;
}

void main() {
  final wrapped_store = WrappedStore();
  var next = store.dispatch;
  wrapped_store.dispatch = (action) {
    print('dispatching ${action}');
    next(action);
    print('next state ${store.state}');
  };
}
```

This is already closer to what we want! No matter where we dispatch
an action, it is guaranteed to be logged. Wrapping never feels
right, but we can live with this for now.

## Problem: Crash Reporting
What if we want to apply __more than one__ transformation to
`dispatch`?

A different useful transformation that comes to mind is
reporting JavaScript errors in production. The global
`window.onerror` is not reliable because it doesn't
provide stack information in some older browsers, which
is crucial to understand why an error is happening.

Wouldn't it be useful if, any time an error is thrown
as a result of dispatching an action, we would send it to a
crash reporting service [Sentry](https://pub.dev/packages/sentry)
with the stack trace, the action that caused the error,
and the current state? This way it's much easier to
reproduce the error in development.

However, it is important that we keep logging and crash
reporting separate. Ideally we want them to be different
modules, potentially in different packages. Otherwise
we can't have an ecosystem of such utilties.
(Hint: we're slowly getting to what middleware is!)

if logging and crash reporting are separate utilties, they
might look like this:

```dart
void patchStoreToAddLogging(WrappedStore store) {
  var next = store.dispatch;
  store.dispatch = (action) {
    print('dispatching ${action}');
    next(action);
    print('next state ${store.state}');
  };
}

void patchStoreToAddCrashReporting(WrappedStore store) {
  var next = store.dispatch;
  store.dispatch = (action) {
    try {
      return next(action);
    } catch (err) {
      print('Caught an exception!\n${err}');
    }
  };
}
```

If these functions are published as separate modules, we can later
use them to patch our store:

```dart
patchStoreToAddLogging(wrapped_store);
patchStoreToAddCrashReporting(wrapped_store);
```

## Attempt #4 Hiding Monkeypatching

Monkeypatching is a hack. "Replace any method you like", what kind
of API is that? Let's figure out the essence of it instead.
Previously, our functions replaced `store.dispatch`. What if they
_returned_ the new `dispatch` function instead?

```dart
void Function(dynamic) logger(WrappedStore store) {
  var next = store.dispatch;

  return (action) {
    print('dispatching ${action}');
    next(action);
    print('next state ${store.state}');
  };
}

void Function(dynamic) crashReporter(WrappedStore store) {
  var next = store.dispatch;

  return (action) {
    try {
      return next(action);
    } catch (err) {
      print('Caught an exception!\n${err}');
    }
  };
}
```

We could provide a helper inside Redux that would apply the actual
monkeypatching as an implementation detail:

```dart
void applyMiddlewareByMonkeyPatching(
  WrappedStore store,
  List<void Function(dynamic) Function(WrappedStore)> middlewares,
) {
  middlewares.reversed.forEach((middleware) => (store.dispatch = middleware(store)));
}
```

```dart
applyMiddlewareByMonkeyPatching(wrapped_store, [logger, crashReporter]);
```

However, it is still monkeypatching. The fact that we hide it
inside a library doesn't alter this fact.

## Attempt #5: Removing Monkeypatching

Why do we even overwrite `dispatch`? Of course, to be able to call
it later, but there's also another reason: so that every
middleware can access (and call) the previously wrapped
`store.dispatch`:

```dart
void Function(dynamic) logger(WrappedStore store) {
  // Must point to the function returned by the previous middleware:
  var next = store.dispatch;

  return (action) {
    print('dispatching ${action}');
    next(action);
    print('next state ${store.state}');
  };
}
```

It is essential to chaining middleware!

If `applyMiddlewareByMonkeyPatching` doesn't assign
`store.dispatch` immediately after processing the first middleware,
`store.dispatch` will keep pointing to the original `dispatch`
function.

But there's also a different way to enable chaining. The middleware
could accept the `next()` dispatch function as a parameter
instead of reading it from the `store` instance.

```dart
void logger(Store<AppState> store, action, void Function(dynamic) next) {
  print('dispatching ${action}');
  next(action);
  print('next state ${store.state}');
}
```

To simplify the type signature, Redux defines a type called
`NextDispatcher`, which is an alias for `void Function(dynamic)`,
which makes the function signature easier on eyes:

```dart
void logger(Store<AppState> store, action, NextDispatcher next) {
  print('dispatching ${action}');
  next(action);
  print('next state ${store.state}');
}

void crashReporter(Store<AppState> store, action, NextDispatcher next) {
  try {
    return next(action);
  } catch (err) {
    print('Caught an exception!\n${err}');
  }
}
```
__This is exactly what Redux middleware looks like__.

Now middleware takes the `next()` dispatch function, and serves
as `next()` to the
middleware to the left, and so on. It's still useful to have
access to some store properties like `state`, so `store` stays
available as the top-level argument.

## Attempt #6: Naïvely Applying the Middleware

Instead of `applyMiddlewareByMonkeypatching()`, we could write
a constructor for `WrappedStore` that obtains the final,
fully wrapped `dispatched()` function:

```dart
WrappedStore({List<void Function(Store<AppState>, dynamic, void Function(dynamic))> middlewares}) {
  var next = dispatch;
  middlewares.reversed.forEach((middleware) => {dispatch = (action) => middleware(store, action, next)});
}
```

The implementation of `Store` that ships with Redux is
similar, __but different in two important aspects:__

* It only exposes a subset of the [store API](https://pub.dev/documentation/redux/latest/redux/Store-class.html)
to the middleware: [dispatch(action)](https://pub.dev/documentation/redux/latest/redux/Store/dispatch.html)
and [state](https://pub.dev/documentation/redux/latest/redux/Store/state.html).

* It does a bit of trickery to make sure that if you call
`store.dispatch(action)` from your middleware instead of
`next(action)`, the action will actually travel the whole
middleware chain again, including the current middleware.
This is useful for asynchronous middleware, as we have seen
[previously](async_actions.md).

## The Final Approach

Given this middleware we just wrote:

```dart
void logger(Store<AppState> store, action, NextDispatcher next) {
  print('dispatching ${action}');
  next(action);
  print('next state ${store.state}');
}

void crashReporter(Store<AppState> store, action, NextDispatcher next) {
  try {
    return next(action);
  } catch (err) {
    print('Caught an exception!\n${err}');
  }
}
```

Here's how to apply it to a Redux store:

```dart
Store store = Store<AppState>(
  appStateReducer,
  initialState: AppState.emptyState(),
  middleware: [logger, crashReporter],
);
```

That's it! Now any actions dispatched to the store instance
will flow through `logger` and `crashReporter`:

```dart
// Will flow through both logger and crashReporter middleware!
store.dispatch(AddTodo('Use Redux'));
```

## Seven Examples

TODO
