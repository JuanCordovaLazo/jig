/// A failure the agent can act on.
///
/// Every arm of this enum exists because a caller needs to branch on it:
/// [elementNotFound] and [elementAmbiguous] mean "look at [JigError.candidates]",
/// [evalFailed] means "the expression is wrong, not the app", and
/// [extensionUnavailable] means "jig is not installed in this build".
enum JigErrorCode {
  elementNotFound('ELEMENT_NOT_FOUND'),
  elementNotVisible('ELEMENT_NOT_VISIBLE'),
  elementAmbiguous('ELEMENT_AMBIGUOUS'),
  elementNotEditable('ELEMENT_NOT_EDITABLE'),
  evalFailed('EVAL_FAILED'),
  extensionUnavailable('EXTENSION_UNAVAILABLE'),
  notConnected('NOT_CONNECTED'),
  timeout('TIMEOUT'),
  scrollExhausted('SCROLL_EXHAUSTED'),
  backRefused('BACK_REFUSED'),
  clearRefused('CLEAR_REFUSED'),
  adjustRefused('ADJUST_REFUSED'),
  gestureNoEffect('GESTURE_NO_EFFECT'),
  expectationFailed('EXPECTATION_FAILED'),
  invalidSelector('INVALID_SELECTOR'),
  invalidArgument('INVALID_ARGUMENT'),
  internal('INTERNAL');

  const JigErrorCode(this.wire);

  /// The stable string a frontend prints. Enum names are not a contract.
  final String wire;
}

final class JigError {
  const JigError(
    this.code,
    this.message, {
    this.candidates = const <String>[],
    this.hint,
  });

  final JigErrorCode code;
  final String message;

  /// Nearby matches that may have been what the caller meant.
  final List<String> candidates;

  /// The next command to try, phrased as something copy-pasteable.
  final String? hint;

  Map<String, Object?> toJson() => <String, Object?>{
        'code': code.wire,
        'message': message,
        if (candidates.isNotEmpty) 'candidates': candidates,
        if (hint != null) 'hint': hint,
      };

  @override
  String toString() => '${code.wire}: $message';
}
