# Async Actions

In the [basics guide](https://github.com/UnHumbleBen/redux-dart-basic-tutorial#basics), we built a simple todo
application. It was fully synchronous. Every time an action was
dispatched, the state was updated immediately.

In this guide, we will build a different, asynchronous application.
It will use the Reddit API to show the current headlines for a
selected subreddit. How does asynchronicity fit into Redux flow?

## Actions

When you call an asynchronous API, there are two crucial moments in
time: the moment you start the call, and the moment when you
receive an answer (or a timeout).

Each of these two moments usually require a change in the
application state; to do that, you need to dispatch normal actions
that will be processed by reducers synchronously. Usually, for any
API request, you'll want ot dispatch at least three different
kinds of action:

* __An action informing the reducers that the request began.__

The reducer may handle this action by toggling an `isFetching` flag
in the state. This way the UI knows it's time to show a spinner.

* __An action informing the reducers that the request finished
successfully.__

The reducers may handle the action by merging the new data into the
state they manage and resetting `isFetching`. The UI would hide the
spinner, and display the fetched data.

* __An action informing the reducers that the request failed__.

The reducers may handle the action by resetting the `isFetching`.
Additionally, some reducers may want to store the error message
so the UI can display it.

You may use a dedicated `status` field in your actions:
```js
{ type: 'FETCH_POSTS' }
{ type: 'FETCH_POSTS', status: 'error', error: 'Oops' }
{ type: 'FETCH_POSTS', status: 'success', response: { ...} }
```

Or you can define separate types for them:

```js
{ type: 'FETCH_POSTS_REQUEST' }
{ type: 'FETCH_POSTS_FAILURE', error: 'Oops' }
{ type: 'FETCH_POSTS_SUCCESS', response: { ... } }
```

Choosing whether to use a single action type with flags,
or multiple action types, is up to you. It's a convention
you need to decide with your team. Multiple types leave less
room for a mistake.

Whatever convention you choose, stick with it throughout the
application. We'll use separate types in this tutorial.

## Synchronous Actions

Let's start by defining the several synchronous action types
we need in our example app. Here, the user can select a
subreddit to display:

__`lib/src/actions.dart` (Synchronous)__
```dart
class SelectSubreddit {
  String subreddit;

  SelectSubreddit({this.subreddit});

  Map<String, dynamic> toJson() {
    return {'type': 'SelectSubreddit', 'subreddit': subreddit};
  }
}
```

They can also press a "refresh" button to update it:

```dart
class InvalidateSubreddit {
  String subreddit;

  InvalidateSubreddit({this.subreddit});

  Map<String, dynamic> toJson() {
    return {'type': 'InvalidateSubreddit', 'subreddit': subreddit};
  }
}
```

These were the actions goverend by th euser interaction.
We will also have another kind of action, governed by the network
requests. We will see how to dispatch them later, but for now,
we just want to define them.

When it's time to fetch the posts for some subreddit,
we will dispatch a `RequestPosts` action:

```dart
class RequestPosts {
  String subreddit;

  RequestPosts({this.subreddit});

  Map<String, dynamic> toJson() {
    return {'type': 'RequestPosts', 'subreddit': subreddit};
  }
}
```

It is important for it to be separate from `SelectSubreddit`
or `InvalidateSubreddit`. While they may occur one after another,
as the app grows more complex, you might want to fetch some
data indepdently of the user action (for example, to prefetch
the most popular subreddits, or to refresh stale data once in
a while). You may also want ot fetch in response to a route change,
so it's not wise to couple fetching to some particular UI event
early on.

Finally, when the network request comes through, we will dispatch
`ReceivePosts`:

```dart
class ReceivePosts {
  String subreddit;
  List<dynamic> posts;
  DateTime recievedAt;

  ReceivePosts({this.subreddit, this.posts}) : recievedAt = DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'type': 'ReceivePosts',
      'subreddit': subreddit,
      'posts': posts,
      'recievedAt': recievedAt.toString(),
    };
  }
}
```

This is all we need to know for now. The particular mechnaism to
dispatch these actions together with network requests will be
discussed later.

> __Note on Error Handling__
>
> In a real app, you'd also want to dispatch an action on request
> failure. We won't implement error handling in this tutorial, but
> the [real world example](https://redux.js.org/introduction/examples/#real-world)
shows one of the possible approaches.

## Design the State Shape
Just like in the basic tutorial, you'll need to
[design the shape of your application's state](https://github.com/UnHumbleBen/redux-dart-basic-tutorial#designing-the-state-shape)
before rushing into the implementation.
With asynchronous code, there is more state to take care of,
so we need to think it through.

This part is often confusing to beginners, because it is not
immediately clear what information describes the state of
an asynchronous application, and how to organize it in a single
tree.

We'll start with the most common use case: lists. Web applications
often show lists of things. For example, a list of posts, or a
list of friends. You'll need to figure out what sorts of lists
your app can show. You want to store htem separately in the state,
because this way you can cache them and only fetch again if
necessary.

Here's what the state shape of our "Reddit headlines" app might
look like:

```js
{
  selectedSubreddit: 'frontend',
  postsBySubreddit: {
    frontend: {
      isFetching: true,
      didInvalidate: false,
      items: []
    },
    reactjs: {
      isFetching: false,
      didInvalidate: false,
      lastUpdated: 1439478405547,
      items: [
        {
          id: 42,
          title: 'Confusion about Flux and Relay'
        },
        {
          id: 500,
          title: 'Creating a Simple Application Using React JS and Flux Architecture'
        }
      ]
    }
  }
}
```

There are a few important bits here:

* We store each subreddit's information seperately so we can cache
every subreddit. When the user switches between them the second
time, the update will be instant, and we won't need to refetch
unless we want to. Don't worry about all these items being in
memory: unless you're dealing with tens of thousands of items,
and your user rarely closes the tab, you won't need any sort
of cleanup.

* For every list of items, you'll want to store `isFetching` to
show a spinner, `didInvalidate` so you can latter toggle it
when the data is stale, `lastUpdated` so you know when it was
fetched the last time, and the `items` themselves. In a real
app, you'll also want to store pagination state like
`fetchedPageCount` and `nextPageUrl`.

> __Note on Nexted Entities__
>
> In this example, we store the received items together with the
> pagination information. However, this approach won't work well
> if you have nested entities referencing each other, or if you
> let the user edit items. Imagine the user wants to edit a fetched
> post, but this post is duplicated in several places in the state
> tree. This would be really painful to implement.
>
> If you have nested entities, or if you let users edit received
> entities, you should keep them separately in the state as if it
> was a database. In pagination information, you would only refer
> to them by their IDs. This lets you always keep them up to date.
> The [real world example](https://redux.js.org/introduction/examples#real-world)
> show this approach, together with [normalizr](https://github.com/paularmstrong/normalizr)
> to normalize the nested API responses. With this approach, your
> state might look like this:
> ```js
> {
>   selectedSubreddit: 'frontend',
>   entities: {
>     users: {
>       2: {
>         id: 2,
>         name: 'Andrew'
>       }
>     },
>     posts: {
>       42: {
>         id: 42,
>         title: 'Confusion about Flux and Relay',
>         author: 2
>       },
>       100: {
>         id: 100,
>         title: 'Creating a Simple Application Using React JS and Flux Architecture',
>         author: 2
>       }
>     }
>   },
>   postsBySubreddit: {
>     frontend: {
>       isFetching: true,
>       didInvalidate: false,
>       items: []
>     },
>     reactjs: {
>       isFetching: false,
>       didInvalidate: false,
>       lastUpdated: 1439478405547,
>       items: [ 42, 100 ]
>     }
>   }
> }
> ```
> In this guide, we won't normalize entities, but it's something
> you should consider for a more dynamic application.

## Handling Actions

Before going into the details of dispatching actions together
with network requests, we will write the reducers for the actions
we defined above.

> __Note on Reducer Composition
>
> Here, we assume you understand reducer composition with
> [`combineReducers()`](https://pub.dev/documentation/redux/latest/redux/combineReducers.html),
> as described in the [Splitting Reducers](https://github.com/UnHumbleBen/redux-dart-basic-tutorial#splitting-reducers)
> section on the [basics guide](https://github.com/UnHumbleBen/redux-dart-basic-tutorial#basics).
> If you don't, please [read it first](https://github.com/UnHumbleBen/redux-dart-basic-tutorial#splitting-reducers).

`lib/src/reducers.dart`
```dart
import 'package:redux/redux.dart';
import 'package:redux_dart_advanced_tutorial/src/actions.dart';

class AppState {
  String selectedSubreddit;
  Map<String, Posts> postsBySubreddit;

  AppState({
    this.selectedSubreddit = 'reactjs',
    this.postsBySubreddit = const {},
  });

  @override
  String toString() {
    return toJson().toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'selectedSubreddit': selectedSubreddit,
      'postsBySubreddit': postsBySubreddit,
    };
  }
}

class Posts {
  bool isFetching;
  bool didInvalidate;
  DateTime lastUpdated;
  List<dynamic> items;

  Posts({
    this.isFetching = false,
    this.didInvalidate = false,
    this.lastUpdated,
    this.items = const [],
  });

  @override
  String toString() {
    return toJson().toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'isFetching': isFetching,
      'didInvalidate': didInvalidate,
      'lastUpdated': lastUpdated.toString(),
      'items': items,
    };
  }
}

String selectSubredditReducer(String selectedSubreddit, SelectSubreddit action) {
  return action.subreddit;
}

Reducer<String> selectedSubredditReducer =
    combineReducers<String>([TypedReducer<String, SelectSubreddit>(selectSubredditReducer)]);

Posts invalidateSubredditReducer(Posts posts, InvalidateSubreddit action) {
  return Posts(
    didInvalidate: true,
  );
}

Posts requestPostsReducer(Posts posts, RequestPosts action) {
  return Posts(
    isFetching: true,
    didInvalidate: false,
  );
}

Posts receivePostsReducer(Posts posts, ReceivePosts action) {
  return Posts(
    isFetching: false,
    didInvalidate: false,
    items: action.posts,
    lastUpdated: action.recievedAt,
  );
}

Reducer<Posts> postsReducer = combineReducers<Posts>([
  TypedReducer<Posts, InvalidateSubreddit>(invalidateSubredditReducer),
  TypedReducer<Posts, RequestPosts>(requestPostsReducer),
  TypedReducer<Posts, ReceivePosts>(receivePostsReducer),
]);

Map<String, Posts> postsBySubredditReducer(Map<String, Posts> postsBySubreddit, dynamic action) {
  if (action is InvalidateSubreddit || action is RequestPosts || action is ReceivePosts) {
    return Map.from(postsBySubreddit)
      ..addEntries([MapEntry(action.subreddit, postsReducer(postsBySubreddit[action.subreddit], action))]);
  } else {
    return postsBySubreddit;
  }
}

AppState appStateReducer(AppState state, dynamic action) => AppState(
      postsBySubreddit: postsBySubredditReducer(state.postsBySubreddit, action),
      selectedSubreddit: selectedSubredditReducer(state.selectedSubreddit, action),
    );
```

In this code, there are two interesting parts:

* We use Dart's cascade notation so we can update
`postsBySubreddit[action.subreddit]` with
`Map.addEntries()` in a concise way. This:

```dart
return Map.from(postsBySubreddit)
  ..addEntries([MapEntry(action.subreddit, postsReducer(postsBySubreddit[action.subreddit], action))]);
```

is equivalent to this:

```dart
var nextPostsBySubreddit = Map.from(postsBySubreddit);
nextPostsBySubreddit
    .addEntries([MapEntry(action.subreddit, postsReducer(postsBySubreddit[action.subreddit], action))]);
return nextPostsBySubreddit;
```

* We extracted `postsReducer` that manges the state of a
specific post list. This is just [reducer composition](https://github.com/UnHumbleBen/redux-dart-basic-tutorial#splitting-reducers)!
It is our choice how to split the reducer into smaller reducers,
and in this case, we're delgating updating items inside an
object to a `Posts` reducer. The [real world example](https://redux.js.org/introduction/examples#real-world)
goes even further, showing how to create a reducer factory
for parameterized pagination reducers.

Remeber that reducers are just functions, so you can use
functional composition and higher-order functions as much
as you feel comfortable.

## Async Actions

Finally, how do we use the synchronous actions we
[defined earlier](#synchronous-actions) together with network
requests? The standard way to do it with Redux is to use
the [Redux Thunk middleware](https://pub.dev/packages/redux_thunk).
It comes in a separate package called `redux_thunk`. We'll
explain how middleware works in general [later](middleware.md);
for now, there is just one important thing you need to know:
by using this specific middleware, you can dispatch
a function instead of an action object to your store. This way, the
action becomes a [thunk](https://en.wikipedia.org/wiki/Thunk).

When an function is dispatched, that function will get
executed by the Redux Thunk middleware. This function doesn't
need to be pure; it is thus allowed to have side effects,
including executing asynchronous API calls. The function
can also dispatch actions&mdash; like those synchronous actions
we defined earlier.

We can still define these special actions inside our
`actions.dart` file:

__`actions.dart` (Asynchronous)__
```dart
import 'dart:convert';
import 'dart:html';

import 'package:redux/redux.dart';
import 'package:redux_dart_advanced_tutorial/src/reducers.dart';
import 'package:redux_thunk/redux_thunk.dart';

class SelectSubreddit {
  String subreddit;

  SelectSubreddit({this.subreddit});

  Map<String, dynamic> toJson() {
    return {'type': 'SelectSubreddit', 'subreddit': subreddit};
  }
}

class InvalidateSubreddit {
  String subreddit;

  InvalidateSubreddit({this.subreddit});

  Map<String, dynamic> toJson() {
    return {'type': 'InvalidateSubreddit', 'subreddit': subreddit};
  }
}

class RequestPosts {
  String subreddit;

  RequestPosts({this.subreddit});

  Map<String, dynamic> toJson() {
    return {'type': 'RequestPosts', 'subreddit': subreddit};
  }
}

class ReceivePosts {
  String subreddit;
  List<dynamic> posts;
  DateTime recievedAt;

  ReceivePosts({this.subreddit, this.posts}) : recievedAt = DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'type': 'ReceivePosts',
      'subreddit': subreddit,
      'posts': posts,
      'recievedAt': recievedAt.toString(),
    };
  }
}

// Meet our first thunk action!
// Though inside are different, you would use it just like
// any other action:
// store.dispatch(fetchPosts('reactjs'))

ThunkAction<AppState> fetchPosts(String subreddit) {
  // Thunk middleare knows how to handle functions..
  // It passes the store as an argument to the function,
  // thus making it able to dispatch actions itself.
  return (Store<AppState> store) async {
    // First dispatch: the app state is updated to inform
    // that the API call is starting.
    store.dispatch(RequestPosts(subreddit: subreddit));

    var path = 'https://www.reddit.com/r/${subreddit}.json';
    await HttpRequest.getString(path).then((String response) {
      Map<String, dynamic> jsonData = json.decode(response);
      List<dynamic> jsonDataChildren = jsonData['data']['children'];
      var posts = jsonDataChildren.map((child) => child['data']).toList();
      store.dispatch(ReceivePosts(subreddit: subreddit, posts: posts));
    }).catchError((error) {
      print('An error occured:\n${error}');
    });
  };
}
```

How do we include the Redux Thunk middleware in the dispatch
mechanism? We use the `middleware` argument of the
[`Store()`](https://pub.dev/documentation/redux/latest/redux/Store/Store.html) constructor as showm below:

`lib/src/store.dart`
```dart
import 'package:over_react/over_react_redux.dart';
import 'package:redux/redux.dart';
import 'package:redux_dart_advanced_tutorial/src/reducers.dart';
import 'package:redux_dev_tools/redux_dev_tools.dart';
import 'package:redux_thunk/redux_thunk.dart';

final PRODUCTION = false;

final store = PRODUCTION
    ? Store<AppState>(
        appStateReducer,
        initialState: AppState(),
        middleware: [
          thunkMiddleware, // lets us dispatch() functions
        ],
      )
    : DevToolsStore<AppState>(
        appStateReducer,
        initialState: AppState(),
        middleware: [
          thunkMiddleware, // lets us dispatch() functions
          overReactReduxDevToolsMiddleware // lets us use Redux DevTools browser extension
        ],
      );
```

`web/main.dart`
```dart
import 'dart:html';

import 'package:redux_dart_advanced_tutorial/src/actions.dart';
import 'package:redux_dart_advanced_tutorial/src/store.dart';

void main() {
  querySelector('#output').text = 'Your Dart app is running.';

  store.dispatch(SelectSubreddit(subreddit: 'reactjs'));
  store.dispatch(fetchPosts('reactjs'));
}
```

The nice things about thunks is that they can dispatch results
of each other:

__`action.dart` (Asynchronous)__
```dart
import 'dart:convert';
import 'dart:html';

import 'package:redux/redux.dart';
import 'package:redux_dart_advanced_tutorial/src/reducers.dart';
import 'package:redux_thunk/redux_thunk.dart';

class SelectSubreddit {
  String subreddit;

  SelectSubreddit({this.subreddit});

  Map<String, dynamic> toJson() {
    return {'type': 'SelectSubreddit', 'subreddit': subreddit};
  }
}

class InvalidateSubreddit {
  String subreddit;

  InvalidateSubreddit({this.subreddit});

  Map<String, dynamic> toJson() {
    return {'type': 'InvalidateSubreddit', 'subreddit': subreddit};
  }
}

class RequestPosts {
  String subreddit;

  RequestPosts({this.subreddit});

  Map<String, dynamic> toJson() {
    return {'type': 'RequestPosts', 'subreddit': subreddit};
  }
}

class ReceivePosts {
  String subreddit;
  List<dynamic> posts;
  DateTime recievedAt;

  ReceivePosts({this.subreddit, this.posts}) : recievedAt = DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'type': 'ReceivePosts',
      'subreddit': subreddit,
      'posts': posts,
      'recievedAt': recievedAt.toString(),
    };
  }
}

ThunkAction<AppState> fetchPosts(String subreddit) {
  return (Store<AppState> store) async {
    store.dispatch(RequestPosts(subreddit: subreddit));

    var path = 'https://www.reddit.com/r/${subreddit}.json';
    await HttpRequest.getString(path).then((String response) {
      Map<String, dynamic> jsonData = json.decode(response);
      List<dynamic> jsonDataChildren = jsonData['data']['children'];
      var posts = jsonDataChildren.map((child) => child['data']).toList();
      store.dispatch(ReceivePosts(subreddit: subreddit, posts: posts));
    }).catchError((error) {
      print('An error occured:\n${error}');
    });
  };
}

bool shouldFetchPosts(AppState state, String subreddit) {
  var posts = state.postsBySubreddit[subreddit];
  if (posts == null) {
    return true;
  } else if (posts.isFetching) {
    return false;
  } else {
    return posts.didInvalidate;
  }
}

ThunkAction<AppState> fetchPostsIfNeeded(String subreddit) {
  // This is useful for avoiding a network request if
  // a cached value is already available.
  return (Store<AppState> store) async {
    if (shouldFetchPosts(store.state, subreddit)) {
      // Dispatch a thunk from thunk!
      store.dispatch(fetchPosts(subreddit));
    }
  };
}
```

This lets us write more sophisticated async control flow gradually,
while the consuming code can stay pretty much the same:

`web/main.dart`
```dart
import 'dart:html';

import 'package:redux_dart_advanced_tutorial/src/actions.dart';
import 'package:redux_dart_advanced_tutorial/src/store.dart';

void main() {
  querySelector('#output').text = 'Your Dart app is running.';

  store.dispatch(SelectSubreddit(subreddit: 'reactjs'));
  store.dispatch(fetchPostsIfNeeded('reactjs'));
}
```

> __Note about Server Rendering__
>
> Async actions are especially convenient for server
> rendering. You can create a store, dispatch a single async
> action that dispatches other async actions to fetch data
> for a whole section of your app, and only render after
> the Future it returns, completes. Then your store
> will already be hydrated with the state you need before
> rendering.

[Thunk middleware](https://pub.dev/packages/redux_thunk)
isn't the only way to orchestrate asynchronous actions in
Redux:
* You can use [redux_future](https://pub.dev/packages/redux_future)
or [redux_future_middleware](https://pub.dev/packages/redux_future_middleware) to dispatch Dart Futures instead of functions.
* You can use [redux_epics](https://pub.dev/packages/redux_epics)
to dispatch Observables.
* You can even write a custom middleware to describe calls to your
API, like the [real world example](https://redux.js.org/introduction/examples#real-world) does.

It is up to you to try a few options, choose a convention
you like, and follow it, whether with, or without the middleware.

## Connecting to UI

Dispatching async actions is no different from dispatching
synchronous actions, so we won't discuss this in detail. See
[Usage with OverReact](https://github.com/UnHumbleBen/redux-dart-basic-tutorial#usage-with-overreact)
for an introduction into using Redux from OverReact components.
See [Example: Reddit API](example_reddit_api.md) for the complete
source code discussed in this example.

## Next Steps

Read [Async Flow](async_flow.md) to recap how async actions fit into Redux
flow.
