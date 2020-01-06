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
