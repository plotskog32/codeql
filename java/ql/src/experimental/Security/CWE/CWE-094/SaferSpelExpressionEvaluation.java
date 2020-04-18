public Object evaluate(Socket socket) throws IOException {
  try (BufferedReader reader = new BufferedReader(
      new InputStreamReader(socket.getInputStream()))) {

    String string = reader.readLine();
    ExpressionParser parser = new SpelExpressionParser();
    Expression expression = parser.parseExpression(string);
    SimpleEvaluationContext context 
        = SimpleEvaluationContext.forReadWriteDataBinding().build();
    return expression.getValue(context);
  }
}