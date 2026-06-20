sealed class AppResult<T> {
  const AppResult();

  bool get isSuccess => this is AppSuccess<T>;
}

class AppSuccess<T> extends AppResult<T> {
  const AppSuccess(this.value);
  final T value;
}

class AppFailure<T> extends AppResult<T> {
  const AppFailure(this.message);
  final String message;
}

class AppConfirmationRequired<T> extends AppFailure<T> {
  const AppConfirmationRequired({
    required this.code,
    required String message,
    required this.payload,
  }) : super(message);

  final String code;
  final Object payload;
}
