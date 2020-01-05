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
