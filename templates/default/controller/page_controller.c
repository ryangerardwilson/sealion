#include "../src/app.h"

#include <stdio.h>

void handle_api_me(int client, const Request *req) {
  User user;
  if (current_user(req, &user)) {
    char email[512];
    char json[1024];
    json_escape(email, sizeof(email), user.email);
    snprintf(json, sizeof(json), "{\"authenticated\":true,\"user\":{\"email\":\"%s\"}}", email);
    respond_json(client, "200 OK", NULL, json);
    return;
  }
  respond_json(client, "200 OK", NULL, "{\"authenticated\":false,\"user\":null}");
}

void handle_api_dashboard(int client, const Request *req) {
  User user;
  if (!current_user(req, &user)) {
    respond_json(client, "401 Unauthorized", NULL, "{\"ok\":false,\"error\":\"Authentication required.\"}");
    return;
  }
  char email[512];
  char json[1024];
  json_escape(email, sizeof(email), user.email);
  snprintf(
    json,
    sizeof(json),
    "{\"ok\":true,\"user\":{\"email\":\"%s\"},\"message\":\"This dashboard is backed by the C API and Postgres.\"}",
    email
  );
  respond_json(client, "200 OK", NULL, json);
}

void handle_not_found(int client) {
  respond_json(client, "404 Not Found", NULL, "{\"ok\":false,\"error\":\"Route not found.\"}");
}
