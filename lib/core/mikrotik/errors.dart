/// Erreurs levées par les clients de connexion MikroTik.
class RitikException implements Exception {
  final String message;
  const RitikException(this.message);

  @override
  String toString() => message;
}

class RouterosException extends RitikException {
  const RouterosException(super.message);
}

class RestException extends RitikException {
  const RestException(super.message);
}

class NotConnectedException extends RitikException {
  const NotConnectedException([String m = 'Non connecté au routeur'])
      : super(m);
}