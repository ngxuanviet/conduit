class TypeCoercionException implements Exception {
  TypeCoercionException(this.expectedType, this.actualType);

  final String expectedType;
  final Type actualType;

  @override
  String toString({bool includeActualType = false}) {
    final trailingString = includeActualType ? " (input is '$actualType')" : "";
    return "input is not expected type '$expectedType'$trailingString";
  }
}
