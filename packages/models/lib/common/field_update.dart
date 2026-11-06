sealed class FieldUpdate<T> {
  const FieldUpdate();
}

final class KeepField<T> extends FieldUpdate<T> {
  const KeepField();
}

final class SetField<T> extends FieldUpdate<T> {
  final T value;

  const SetField(this.value);
}
