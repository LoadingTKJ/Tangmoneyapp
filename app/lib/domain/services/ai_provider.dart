abstract class AIProvider {
  Future<String> classify(Map<String, Object?> transaction);
  Future<String> nlQuery(String query);
}
