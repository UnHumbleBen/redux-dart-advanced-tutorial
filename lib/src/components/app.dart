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
