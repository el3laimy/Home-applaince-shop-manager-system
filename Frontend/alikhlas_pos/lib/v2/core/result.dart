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
