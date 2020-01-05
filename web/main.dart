import 'dart:html';

// import 'package:redux_dart_advanced_tutorial/src/actions.dart';
// import 'package:redux_dart_advanced_tutorial/src/store.dart';

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
  // store.onChange.listen(print);
  // store.dispatch(SelectSubreddit(subreddit: 'reactjs'));
  // store.dispatch(fetchPostsIfNeeded('reactjs'));
}
