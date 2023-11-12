class SnackBarMessage {
  final String _message;
  bool shown = false;

  SnackBarMessage(this._message);

  String getMessage() {
    shown = true;
    return _message;
  }
}