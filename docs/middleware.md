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
Only works in [JavaScript](https://redux.js.org/advanced/middleware).

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
crash reporting service
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

TODO: complete this...

## Seven Examples