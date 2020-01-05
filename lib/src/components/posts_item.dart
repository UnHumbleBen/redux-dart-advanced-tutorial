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
