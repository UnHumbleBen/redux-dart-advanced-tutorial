# Example: Reddit API

This is the complete source code of the Reddit headline fetching
example we built during the [advanced tutorial](../README.md).

## Entry Point

`web/main.dart`
```dart
import 'dart:html';

import 'package:over_react/over_react.dart';
import 'package:over_react/over_react_redux.dart';
import 'package:over_react/react_dom.dart' as react_dom;
import 'package:redux_dart_advanced_tutorial/redux_dart_advanced_tutorial.dart';

void main() {
  setClientConfiguration();

  final output = querySelector('#output');

  final app = (ErrorBoundary()((ReduxProvider()..store = store)(
    ConnectedApp()(),
  )));

  react_dom.render(app, output);
}
```

## Actions and Constants
`lib/src/actions.dart`
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
  return (Store<AppState> store) async {
    if (shouldFetchPosts(store.state, subreddit)) {
      // Dispatch a thunk from thunk!
      store.dispatch(fetchPosts(subreddit));
    }
  };
}
```

## Reducers

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

  // For experimentation
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

## Store

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

## Container Components

`lib/src/components/app.dart`
```dart
import 'package:over_react/over_react.dart';
import 'package:over_react/over_react_redux.dart';
import 'package:redux_dart_advanced_tutorial/src/actions.dart';
import 'package:redux_dart_advanced_tutorial/src/components/picker.dart';
import 'package:redux_dart_advanced_tutorial/src/components/posts_item.dart';
import 'package:redux_dart_advanced_tutorial/src/reducers.dart';
part 'app.over_react.g.dart';

@Factory()
UiFactory<AppProps> App = _$App;

@Props()
class _$AppProps extends UiProps with ConnectPropsMixin {
  String selectedSubreddit;
  List<dynamic> posts;
  bool isFetching;
  DateTime lastUpdated;
}

@Component2()
class AppComponent extends UiComponent2<AppProps> {
  @override
  void componentDidMount() {
    props.dispatch(fetchPostsIfNeeded(props.selectedSubreddit));
  }

  @override
  void componentDidUpdate(Map prevProps, Map prevState, [snapshot]) {
    var tPrevProps = typedPropsFactory(prevProps);
    if (props.selectedSubreddit != tPrevProps.selectedSubreddit) {
      props.dispatch(fetchPostsIfNeeded(props.selectedSubreddit));
    }
  }

  void handleChange(nextSubreddit) {
    props.dispatch(SelectSubreddit(subreddit: nextSubreddit));
    props.dispatch(fetchPostsIfNeeded(nextSubreddit));
  }

  void handleRefreshClick(SyntheticMouseEvent e) {
    e.preventDefault();

    props.dispatch(InvalidateSubreddit(subreddit: props.selectedSubreddit));
    props.dispatch(fetchPostsIfNeeded(props.selectedSubreddit));
  }

  @override
  dynamic render() {
    var paragraph_children = [];
    if (props.lastUpdated != null) {
      paragraph_children.add((Dom.span()..key = props.lastUpdated.hashCode)(
        'Last updated at ${props.lastUpdated.toLocal().toString()}',
      ));
    }
    if (!props.isFetching) {
      paragraph_children.add((Dom.button()
        ..onClick = handleRefreshClick
        ..key = props.isFetching.hashCode)(
        'Refresh',
      ));
    }
    var div_children = [];
    if (props.posts.isEmpty) {
      var h2_text = props.isFetching ? 'Loading...' : 'Empty';
      div_children.add((Dom.h2()..key = h2_text.hashCode)(
        h2_text,
      ));
    }
    if (!props.isFetching && props.posts.isNotEmpty) {
      div_children.add((Dom.div()
        ..style = {'opacity': props.isFetching ? 0.5 : 1}
        ..key = props.posts.hashCode)(
        (PostsItem()
          ..posts = props.posts
          ..key = props.posts.hashCode)(),
      ));
    }
    return (Dom.div())(
      (Picker()
        ..value = props.selectedSubreddit
        ..onChangeCallback = handleChange
        ..options = ['reactjs', 'frontend'])(),
      (Dom.p())(
        paragraph_children,
      ),
      div_children,
    );
  }
}

AppProps mapStateToProps(AppState state) {
  bool isFetching;
  DateTime lastUpdated;
  List<dynamic> items;

  var posts = state.postsBySubreddit[state.selectedSubreddit];

  if (posts != null) {
    isFetching = posts.isFetching;
    lastUpdated = posts.lastUpdated;
    items = posts.items;
  } else {
    isFetching = true;
    items = [];
  }

  return App()
    ..selectedSubreddit = state.selectedSubreddit
    ..posts = items
    ..isFetching = isFetching
    ..lastUpdated = lastUpdated;
}

UiFactory<AppProps> ConnectedApp = connect<AppState, AppProps>(
  mapStateToProps: mapStateToProps,
)(App);
```

## Presentational Components
`lib/src/components/picker.dart`
```dart
import 'package:over_react/over_react.dart';
part 'picker.over_react.g.dart';

@Factory()
UiFactory<PickerProps> Picker = _$Picker;

@Props()
class _$PickerProps extends UiProps {
  List<String> options;
  String value;
  void Function(String) onChangeCallback;
}

@Component2()
class PickerComponent extends UiComponent2<PickerProps> {
  @override
  dynamic render() {
    return (Dom.span())(
      (Dom.h1())(
        props.value,
      ),
      (Dom.select()
        ..onChange = ((e) => props.onChangeCallback(e.target.value))
        ..value = props.value)(
        props.options.map(
          (option) => ((Dom.option()
            ..value = option
            ..key = option)(
            option,
          )),
        ),
      ),
    );
  }
}
```

`lib/src/components/posts_item.dart`
```dart
import 'package:over_react/over_react.dart';
part 'posts_item.over_react.g.dart';

@Factory()
UiFactory<PostsItemProps> PostsItem = _$PostsItem;

@Props()
class _$PostsItemProps extends UiProps {
  List<dynamic> posts;
}

@Component2()
class PostsItemComponent extends UiComponent2<PostsItemProps> {
  @override
  dynamic render() {
    return (Dom.ul())(
      props.posts
          .asMap()
          .map((i, post) => (MapEntry(
              i,
              (Dom.li()..key = i)(
                post['title'],
              ))))
          .values
          .toList(),
    );
  }
}
```
