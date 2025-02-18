function handler(event) {
    var request = event.request;
    if (request.uri.startsWith("/starting/")) {
        request.uri = "/loading_sandbox.html";
    }
    return request;
}