#import('dart:io');

void main() {
  String host = '192.168.1.138';
  int port = 50000;
  HttpServer server = new HttpServer();
  WebSocketHandler wsh = new WebSocketHandler();

  // Create a request handler on ws://localhost:50000/ws
  server.addRequestHandler((req) => req.path == "/stockfish", wsh.onRequest);

  // Create a stockfish process and passthru WebSocket data to it.
  wsh.onOpen = (WebSocketConnection connection) {
    var stockfish = Process.start('stockfish', []);
    var stdout = new StringInputStream(stockfish.stdout);

    // Pass output from stockfish to WebSocket.
    stdout.onLine = () => connection.send(stdout.readLine());
    
    // Send a notready string if process is not yet started.
    connection.onMessage = (String message) => connection.send("notready");
    
    // Once process is started send all data from WebSocket to stockfish.
    stockfish.onStart = () =>
        connection.onMessage = ((String message) {
            print(message);
            stockfish.stdin.writeString("$message\n");
        });

    // Close stockfish connection when WebSocket disconnects.
    connection.onClosed = (int status, String reason) => stockfish.close();
    connection.onError = (Event e) => stockfish.close();

    // Close WebSocket connection if stockfish exits.
    stockfish.onExit = (int exitCode) =>
        connection.close(exitCode, "stockfish: disconnected");
  };

  // Listen for connections on broadcast address.
  server.listen(host, port);
}
