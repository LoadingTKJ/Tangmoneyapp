abstract class BankConnector {
  Future<void> connect();
  Future<List<String>> listAccounts();
  Future<List<String>> listTransactions(DateTime from, DateTime to);
}
