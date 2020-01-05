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
