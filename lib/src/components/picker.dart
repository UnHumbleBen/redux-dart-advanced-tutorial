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
