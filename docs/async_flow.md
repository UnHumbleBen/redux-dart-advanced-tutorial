# Async Flow

Without [middleware](middleware.md), Redux store only supports
[synchronous data flow](https://github.com/UnHumbleBen/redux-dart-basic-tutorial#data-flow). This is what you get
by default with [Store()](https://pub.dev/documentation/redux/latest/redux/Store/Store.html).

You may enhance [Store()](https://pub.dev/documentation/redux/latest/redux/Store/Store.html)
with `middleware`. It is not required, but it lets you
[express asynchronous actions in a convenient way](async_actions.md).

Asynchrnous middleware like
[redux_thunk](https://pub.dartlang.org/packages/redux_thunk)
or
[redux_future](https://pub.dartlang.org/packages/redux_future)
wraps the [Store](https://pub.dev/documentation/redux/latest/redux/Store-class.html)
class and allows you to dispatch something other than actions,
for example, functions or Futures. Any middleware you use can then
interpret anything you dispatch, and in turn, can pass actions
to the next middleware in the chain. For example, a Future
middleware can interpret Futures and dispatch a pair of begin/end
actions asynchronously in response to each Future.

When the last middleware in the chain dispatches an action,
it has to be a plain object. This is when the
[synchronous Redux data flow](https://github.com/UnHumbleBen/redux-dart-basic-tutorial#data-flow) takes place.

Check out [the full source code for the async example](example_reddit_api.md).

## Next Steps

Now that you've seen an example of what middleware can do in
Redux, it's time to learn how it actually works,
and how you can create your own. Go on to the next detailed section
about [Middleware](middleware.md).
